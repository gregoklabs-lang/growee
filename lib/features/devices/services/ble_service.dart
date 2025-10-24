import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import 'package:logger/logger.dart';

class BleService {
  BleService._();
  static final BleService I = BleService._();

  final Logger _log = Logger();

  BluetoothDevice? _connected;
  StreamSubscription<List<ScanResult>>? _scanSub;
  BluetoothCharacteristic? _provisioningChar;
  StreamSubscription<List<int>>? _notifySub;
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();
  String? _lastStatusMessage;

  static const String _serviceUuid = '12345678-1234-1234-1234-1234567890ab';
  static const String _characteristicUuid =
      '87654321-4321-4321-4321-0987654321ba';

  // Exponer el device conectado (solo lectura)
  BluetoothDevice? get connectedDevice => _connected;
  Stream<String> get statusStream => _statusController.stream;
  String? get lastStatusMessage => _lastStatusMessage;

  void _emitStatus(List<int> data) {
    if (_statusController.isClosed) return;
    if (data.isEmpty) return;
    final message = utf8.decode(data, allowMalformed: true).trim();
    if (message.isEmpty) return;
    _lastStatusMessage = message;
    _statusController.add(message);
    _log.i('Estado ESP32: $message');
  }

  bool _uuidEquals(Guid uuid, String target) => uuid.str.toLowerCase() == target;

  Future<String?> _prepareProvisioningCharacteristic(
      BluetoothDevice device) async {
    final services = await device.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;

    for (final service in services) {
      if (!_uuidEquals(service.uuid, _serviceUuid)) continue;
      for (final characteristic in service.characteristics) {
        if (_uuidEquals(characteristic.uuid, _characteristicUuid)) {
          targetCharacteristic = characteristic;
          break;
        }
      }
      if (targetCharacteristic != null) break;
    }

    if (targetCharacteristic == null) {
      throw Exception(
          'El ESP32 no expone la característica de provisión esperada.');
    }

    _provisioningChar = targetCharacteristic;
    await targetCharacteristic.setNotifyValue(true);

    await _notifySub?.cancel();
    _notifySub = targetCharacteristic.value.listen(_emitStatus);

    _lastStatusMessage = null;
    try {
      final initialValue = await targetCharacteristic.read();
      _emitStatus(initialValue);
    } catch (e) {
      _log.w('No se pudo leer el valor inicial de la característica: $e');
    }

    return _lastStatusMessage;
  }

  Future<String?> ensureConnectedAndReady(ScanResult result,
      {Duration timeout = const Duration(seconds: 10)}) async {
    if (_connected != null &&
        _connected!.remoteId == result.device.remoteId &&
        _provisioningChar != null) {
      return _lastStatusMessage;
    }

    final device = await connect(result, timeout: timeout);
    return _prepareProvisioningCharacteristic(device);
  }

  Future<void> sendWifiCredentials(
      {required String ssid, required String password}) async {
    final device = _connected;
    if (device == null) {
      throw Exception('No hay un dispositivo BLE listo para provisionar.');
    }

    BluetoothCharacteristic? characteristic = _provisioningChar;
    if (characteristic == null) {
      throw Exception(
          'No se encontró la característica de provisión en el dispositivo BLE.');
    }

    // Verificar estado de conexión y reintentar si se perdió.
    final currentState = await device.connectionState.first;
    if (currentState != BluetoothConnectionState.connected) {
      _log.w(
          'El dispositivo BLE ${device.remoteId.str} no está conectado (estado: $currentState). Intentando reconectar antes de enviar credenciales.');
      try {
        await device.connect(
          timeout: const Duration(seconds: 10),
          autoConnect: false,
        );
        await _waitForConnectionState(
          device,
          BluetoothConnectionState.connected,
          timeout: const Duration(seconds: 10),
        );
        try {
          await device.requestMtu(247);
        } catch (_) {}
        await _prepareProvisioningCharacteristic(device);
        characteristic = _provisioningChar;
        if (characteristic == null) {
          throw Exception(
              'No se pudo preparar la característica de provisión tras reconectar.');
        }
      } on TimeoutException catch (_) {
        throw Exception(
            'No se pudo reconectar con el dispositivo BLE (timeout).');
      } catch (e) {
        throw Exception('Fallo al reconectar con el dispositivo BLE: $e');
      }
    }

    final supportsWrite =
        characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse;
    if (!supportsWrite) {
      throw Exception(
          'La característica de provisión no permite escrituras desde la app.');
    }

    final useWithoutResponse =
        !characteristic.properties.write &&
            characteristic.properties.writeWithoutResponse;

    final payload = utf8.encode('${ssid.trim()}|${password.trim()}');
    try {
      await characteristic.write(payload, withoutResponse: useWithoutResponse);
      _log.i('Credenciales Wi-Fi enviadas al ESP32');
    } on FlutterBluePlusException catch (e) {
      _log.e('Error al enviar credenciales al ESP32', error: e);
      throw Exception(
          'El dispositivo BLE rechazó las credenciales (${e.toString()}).');
    }
  }

  /// Pide permisos necesarios. Devuelve true si todo OK.
  Future<bool> ensurePermissions() async {
    // Android 12+: bluetoothScan & bluetoothConnect. Además ubicación para escanear.
    final result = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // Log de apoyo
    result.forEach((perm, status) {
      _log.d('perm ${perm.toString()}: ${status.toString()}');
    });

    // Si alguno está permanentemente denegado, ofrecemos ir a ajustes desde UI (página)
    if (result.values.any((s) => s.isPermanentlyDenied)) {
      return false;
    }

    // Con que alguno esté denegado, no podemos continuar
    if (result.values.any((s) => s.isDenied || s.isRestricted)) {
      return false;
    }

    return true;
  }

  /// Asegura que el servicio de ubicación del sistema está activo (requerido por Android para escanear BLE).
  Future<bool> ensureLocationServiceOn() async {
    final loc = Location();
    bool enabled = await loc.serviceEnabled();
    if (!enabled) {
      enabled = await loc.requestService();
    }
    return enabled;
  }

  /// Verifica que el adaptador BT esté ON.
  Future<bool> ensureAdapterOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Escanea dispositivos cuyo nombre (o advName) contenga "ESP32".
  /// Devuelve la lista (únicos por remoteId) ordenada por RSSI desc.
  Future<List<ScanResult>> scanEsp32({Duration timeout = const Duration(seconds: 6)}) async {
    final isOn = await ensureAdapterOn();
    if (!isOn) {
      throw Exception('Bluetooth está apagado');
    }

    // Sanear cualquier escaneo previo
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}

    final Map<String, ScanResult> byId = {};
    final completer = Completer<List<ScanResult>>();

    _scanSub?.cancel();
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      bool changed = false;
      for (final r in results) {
        final id = r.device.remoteId.str;
        // Nombre preferido (platformName) y fallback a advName si llega vacío
        final name = (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : r.advertisementData.advName)
            .trim();

        if (name.toUpperCase().contains('ESP32')) {
          if (!byId.containsKey(id) || r.rssi > (byId[id]?.rssi ?? -999)) {
            byId[id] = r;
            changed = true;
          }
        }
      }

      if (changed) {
        // no actualizamos UI aquí; solo acumulamos
      }
    });

    // Arrancar escaneo
    await FlutterBluePlus.startScan(
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
    );

    // Esperar al timeout (startScan corta solo, pero esperamos a que el stream termine)
    await Future.delayed(timeout);
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _scanSub?.cancel();
    _scanSub = null;

    // Preparar salida
    final out = byId.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    if (!completer.isCompleted) {
      completer.complete(out);
    }
    return completer.future;
  }

  /// Conexión directa al dispositivo de un ScanResult.
  /// No usa autoConnect para que la conexión sea inmediata.
  Future<BluetoothDevice> connect(ScanResult r,
      {Duration timeout = const Duration(seconds: 10)}) async {
    // Desconectar el anterior si existe
    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } catch (_) {}
      _connected = null;
    }

    final device = r.device;

    // Conexión
    await device.connect(
      timeout: timeout,
      autoConnect: false,
    );

    // Confirmar estado conectado
    try {
      await _waitForConnectionState(device, BluetoothConnectionState.connected,
          timeout: timeout);
    } on TimeoutException catch (_) {
      throw Exception(
          'No se pudo conectar (timeout esperando estado conectado)');
    }

    // Opcional: establecer MTU más alto (Android). Ignorado en iOS.
    try {
      await device.requestMtu(247);
    } catch (_) {}

    _connected = device;
    _log.i('Conectado a ${device.remoteId.str} (${device.platformName})');
    return device;
  }

  /// Desconectar si hay uno conectado
  Future<void> disconnect() async {
    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } finally {
        _log.i('Desconectado de ${_connected!.remoteId.str}');
        _connected = null;
      }
    }
    await _notifySub?.cancel();
    _notifySub = null;
    _provisioningChar = null;
    _lastStatusMessage = null;
  }

  /// Descubre todos los servicios y características del dispositivo conectado.
  Future<List<BluetoothService>> discoverAllServices() async {
    final d = _connected;
    if (d == null) throw Exception('No hay dispositivo conectado');
    final services = await d.discoverServices();
    _log.d('Descubiertos ${services.length} servicios');
    return services;
  }

  /// Nombre "bonito" por si lo quieres usar en UI.
  String displayName(ScanResult r) {
    final p = r.device.platformName;
    final a = r.advertisementData.advName;
    return (p.isNotEmpty ? p : a).isEmpty ? 'Desconocido' : (p.isNotEmpty ? p : a);
    // Ej.: "ESP32C3_QTPY"
  }

  /// Resetea estado (por si sales de la pantalla y quieres limpiar)
  Future<void> clear() async {
    await _scanSub?.cancel();
    _scanSub = null;
    // no desconectamos aquí intencionalmente
  }

  Future<BluetoothConnectionState> _waitForConnectionState(
    BluetoothDevice device,
    BluetoothConnectionState desired, {
    Duration timeout = const Duration(seconds: 10),
  }) {
    return device.connectionState
        .where((state) => state == desired)
        .first
        .timeout(timeout);
  }
}

import 'dart:async';

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

  // Exponer el device conectado (solo lectura)
  BluetoothDevice? get connectedDevice => _connected;

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
  Future<BluetoothDevice> connect(ScanResult r, {Duration timeout = const Duration(seconds: 10)}) async {
    // Desconectar el anterior si existe
    if (_connected != null) {
      try {
        await _connected!.disconnect();
      } catch (_) {}
      _connected = null;
    }

    final device = r.device;

    // Opcional: establecer MTU más alto (Android). Ignorado en iOS.
    try {
      await device.requestMtu(247);
    } catch (_) {}

    // Conexión
    await device.connect(
      timeout: timeout,
      autoConnect: false,
    );

    // Confirmar estado conectado
    final cs = await device.connectionState.first;
    if (cs != BluetoothConnectionState.connected) {
      throw Exception('No se pudo conectar (estado: $cs)');
    }

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
}

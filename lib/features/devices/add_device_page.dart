// lib/features/devices/add_device_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:logger/logger.dart';

import 'services/ble_service.dart'; // 👈 NUEVO: usamos el servicio BLE

class AddDevicePage extends StatefulWidget {
  const AddDevicePage({super.key});

  @override
  State<AddDevicePage> createState() => _AddDevicePageState();
}

class _AddDevicePageState extends State<AddDevicePage> {
  int _currentStep = 1;
  final List<ScanResult> _scanResults = [];
  int? _selectedIndex;
  bool _isScanning = false;

  List<String> _wifiList = [];
  String? _selectedWifi;
  final TextEditingController _passController = TextEditingController();
  bool _connecting = false;

  final Logger _logger = Logger();

  @override
  void dispose() {
    _passController.dispose();
    super.dispose();
  }

  // === Escaneo BLE usando el servicio ===
  Future<void> _scanAll() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _selectedIndex = null;
    });

    try {
      // 1) Permisos
      final permsOk = await BleService.I.ensurePermissions();
      if (!mounted) return;
      if (!permsOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Otorga permisos de Bluetooth y Ubicación.')),
        );
        setState(() => _isScanning = false);
        return;
      }

      // 2) Ubicación del sistema (Android la exige para escanear BLE)
      final locOn = await BleService.I.ensureLocationServiceOn();
      if (!mounted) return;
      if (!locOn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activa la ubicación del sistema para escanear.')),
        );
        setState(() => _isScanning = false);
        return;
      }

      // 3) Escanear
      final results = await BleService.I.scanEsp32(timeout: const Duration(seconds: 6));
      if (!mounted) return;

      setState(() {
        _scanResults
          ..clear()
          ..addAll(results);
      });

      if (_scanResults.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se detectaron dispositivos ESP32 cercanos.')),
        );
      } else {
        _nextStep();
      }
    } catch (e, st) {
      _logger.e('Error durante escaneo', error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error durante escaneo: $e')),
      );
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  void _nextStep() => setState(() => _currentStep++);
  void _previousStep() =>
      _currentStep == 1 ? Navigator.pop(context) : setState(() => _currentStep--);

  Widget _stepIndicator() {
    Widget dot(int step) {
      final active = _currentStep >= step;
      return CircleAvatar(
        radius: 15,
        backgroundColor: active ? Colors.blueAccent : Colors.grey.shade300,
        child: Text('$step', style: const TextStyle(color: Colors.white)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        dot(1),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(2),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(3),
        Expanded(child: Divider(color: Colors.grey.shade300)),
        dot(4),
      ],
    );
  }

  ButtonStyle _redOutline() => OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: const BorderSide(color: Colors.redAccent, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _backButton() => OutlinedButton(
        onPressed: _previousStep,
        style: _redOutline(),
        child: const Text('Atrás'),
      );

  // === UI Steps (idénticos a tu versión) ===
  Widget _step1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Presiona el botón del ESP32 por 5 segundos y luego presiona Buscar.',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isScanning ? null : _scanAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isScanning
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Buscar', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          _backButton(),
        ],
      );

  Widget _step2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona tu dispositivo ESP32 detectado:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_scanResults.isEmpty)
            const Text('No se encontraron dispositivos ESP32.')
          else
            ..._scanResults.asMap().entries.map((entry) {
              final index = entry.key;
              final r = entry.value;
              final name =
                  r.device.platformName.isEmpty ? 'Desconocido' : r.device.platformName;
              return ListTile(
                title: Text(name),
                subtitle: Text(r.device.remoteId.str),
                trailing: Icon(
                  _selectedIndex == index
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: _selectedIndex == index ? Colors.blueAccent : Colors.grey,
                ),
                onTap: () => setState(() => _selectedIndex = index),
              );
            }),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedIndex == null
                ? null
                : () {
                    setState(() {
                      _wifiList = ['Casa', 'Oficina', 'Invitados', 'ESP32-Test']; // simulación
                    });
                    _nextStep();
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Buscar Wi-Fi', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          _backButton(),
        ],
      );

  Widget _step3() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selecciona la red Wi-Fi del teléfono.',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ..._wifiList.map((ssid) {
            final selected = _selectedWifi == ssid;
            return ListTile(
              title: Text(ssid),
              trailing: Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Colors.blueAccent : Colors.grey,
              ),
              onTap: () => setState(() => _selectedWifi = ssid),
            );
          }),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedWifi == null ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Seleccionar Red', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          _backButton(),
        ],
      );

  Widget _step4() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Red seleccionada: ${_selectedWifi ?? '-'}'),
          const SizedBox(height: 10),
          TextField(
            controller: _passController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _connecting
                ? null
                : () async {
                    if (_passController.text.trim().isEmpty) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa la contraseña.')),
                      );
                      return;
                    }
                    setState(() => _connecting = true);
                    await Future.delayed(const Duration(seconds: 2));
                    if (!mounted) return;
                    setState(() => _connecting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conexión exitosa.')),
                    );
                    Navigator.pop(context);
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _connecting
                ? const Text('Conectando...', style: TextStyle(color: Colors.white))
                : const Text('Conectar', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 12),
          _backButton(),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final steps = [_step1(), _step2(), _step3(), _step4()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Añadir Dispositivo'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _stepIndicator(),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: steps[_currentStep - 1],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

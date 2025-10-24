import 'package:flutter/material.dart';

import '../../core/routes/app_routes.dart';
import 'services/device_registry.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: ValueListenableBuilder<List<DeviceInfo>>(
        valueListenable: DeviceRegistry.I.listenable,
        builder: (context, devices, _) {
          if (devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.bluetooth, size: 64, color: Colors.blueAccent),
                  const SizedBox(height: 16),
                  const Text(
                    'No hay dispositivos añadidos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                  _AddDeviceButton(),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Colors.blueAccent.withValues(alpha: 0.1),
                        child: const Icon(Icons.developer_board, color: Colors.blueAccent),
                      ),
                      title: Text(device.name.isEmpty ? 'Dispositivo ESP32' : device.name),
                      subtitle: Text('ID BLE: ${device.remoteId}'),
                    );
                  },
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemCount: devices.length,
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: _AddDeviceButton(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AddDeviceButton extends StatelessWidget {
  const _AddDeviceButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.addDevice),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('Añadir dispositivo', style: TextStyle(color: Colors.white)),
    );
  }
}

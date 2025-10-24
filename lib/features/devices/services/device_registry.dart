import 'dart:collection';

import 'package:flutter/foundation.dart';

class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.remoteId,
    DateTime? addedAt,
  }) : addedAt = addedAt ?? DateTime.now();

  final String name;
  final String remoteId;
  final DateTime addedAt;

  DeviceInfo copyWith({String? name}) {
    return DeviceInfo(
      name: name ?? this.name,
      remoteId: remoteId,
      addedAt: addedAt,
    );
  }
}

class DeviceRegistry {
  DeviceRegistry._();
  static final DeviceRegistry I = DeviceRegistry._();

  final ValueNotifier<List<DeviceInfo>> _devicesNotifier =
      ValueNotifier<List<DeviceInfo>>(<DeviceInfo>[]);

  ValueListenable<List<DeviceInfo>> get listenable => _devicesNotifier;

  UnmodifiableListView<DeviceInfo> get devices =>
      UnmodifiableListView<DeviceInfo>(_devicesNotifier.value);

  void clear() {
    if (_devicesNotifier.value.isEmpty) return;
    _devicesNotifier.value = <DeviceInfo>[];
  }

  void addOrUpdate(DeviceInfo device) {
    final List<DeviceInfo> current = List<DeviceInfo>.from(_devicesNotifier.value);
    final index = current.indexWhere((d) => d.remoteId == device.remoteId);

    if (index >= 0) {
      final existing = current[index];
      current[index] = existing.copyWith(name: device.name);
    } else {
      current.add(device);
    }

    _devicesNotifier.value = current;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class DeviceTile extends StatelessWidget {
  final BluetoothDevice device;
  final VoidCallback onTap;

  const DeviceTile({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(device.name ?? "Unknown"),
      subtitle: Text(device.address),
      trailing: Icon(Icons.bluetooth),
      onTap: onTap,
    );
  }
}

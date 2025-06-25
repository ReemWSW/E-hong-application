import 'dart:typed_data';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';

class BluetoothService {
  final FlutterBlueClassic _bluetooth = FlutterBlueClassic();
  BluetoothConnection? connection;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    final bonded = await _bluetooth.bondedDevices;
    return bonded ?? [];
  }

  Future<void> connect(BluetoothDevice device) async {
    connection = await _bluetooth.connect(device.address);
  }

  void send(String message) {
    connection?.output.add(Uint8List.fromList(message.codeUnits));
    connection?.output.allSent;
  }

  Future<void> disconnect() async {
    await connection?.close();
    connection = null;
  }

  bool get isConnected => connection?.isConnected ?? false;
}

// lib/bindings/global_binding.dart
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/bluetooth_controller.dart';
import '../services/session_service.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController());           // Auth
    Get.put(BluetoothController());      // Bluetooth
    Get.put(SessionService());           // Session Management
  }
}
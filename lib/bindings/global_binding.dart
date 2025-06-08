import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/bluetooth_controller.dart';

class GlobalBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController());           // Auth
    Get.lazyPut(() => BluetoothController()); // Bluetooth
  }
}

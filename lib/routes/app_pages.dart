import 'package:e_hong_app/views/home_page.dart';
import 'package:e_hong_app/views/login_page.dart';
import 'package:get/get.dart';

import '../bindings/auth_binding.dart';
import '../bindings/bluetooth_binding.dart';

class AppPages {
  static const INITIAL = '/login';

  static final routes = [
    GetPage(name: '/login', page: () => LoginPage(), binding: AuthBinding()),
    GetPage(
      name: '/home',
      page: () => HomePage(),
      binding: BindingsBuilder(() {
        AuthBinding().dependencies();
        BluetoothBinding().dependencies();
      }),
    ),
  ];
}

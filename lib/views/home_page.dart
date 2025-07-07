// lib/pages/home_page.dart (หลังแยก widgets)
import 'package:e_hong_app/services/system_check_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/bluetooth_controller.dart';
import '../services/session_service.dart';
import '../widgets/user_info_section.dart';
import '../widgets/bluetooth_tab.dart';

class HomePage extends StatelessWidget {
  final AuthController authController = Get.find();
  
  HomePage({super.key}) {
    // เพิ่มการ initialize SystemCheckService หากยังไม่มี
    if (!Get.isRegistered<SystemCheckService>()) {
      Get.put(SystemCheckService());
    }
  }

  @override
  Widget build(BuildContext context) {
    final BluetoothController btController = Get.find<BluetoothController>();
    final SessionService sessionService = Get.find<SessionService>();

    return Scaffold(
      appBar: _buildAppBar(sessionService),
      body: GestureDetector(
        onTap: () => sessionService.extendSession(),
        child: Obx(() {
          final user = authController.currentUser.value;
          if (user == null) {
            return Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // User Info Section
              UserInfoSection(
                user: user,
                btController: btController,
              ),
              
              // Bluetooth Tab
              Expanded(
                child: BluetoothTab(
                  btController: btController,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  AppBar _buildAppBar(SessionService sessionService) {
    return AppBar(
      title: Obx(() => Text(
        authController.currentUser.value != null
            ? "สวัสดี ${authController.currentUser.value!.fullName}"
            : "หน้าหลัก",
      )),
      backgroundColor: Colors.blue[600],
      foregroundColor: Colors.white,
      actions: [
        _buildTimerWidget(sessionService),
        _buildLogoutButton(),
        _buildRefreshButton(sessionService),
      ],
    );
  }

  Widget _buildTimerWidget(SessionService sessionService) {
    return Obx(() => Padding(
      padding: EdgeInsets.only(right: 8),
      child: Center(
        child: GestureDetector(
          onTap: _showSessionDialog,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: sessionService.remainingTime.value <= 60
                  ? Colors.red.withOpacity(0.2)
                  : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 16,
                  color: sessionService.remainingTime.value <= 60
                      ? Colors.red[200]
                      : Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  sessionService.formattedRemainingTime,
                  style: TextStyle(
                    fontSize: 12,
                    color: sessionService.remainingTime.value <= 60
                        ? Colors.red[200]
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }

  Widget _buildLogoutButton() {
    return IconButton(
      icon: Icon(Icons.logout),
      onPressed: () => authController.logout(),
      tooltip: "ออกจากระบบ",
    );
  }

  Widget _buildRefreshButton(SessionService sessionService) {
    final btController = Get.find<BluetoothController>();
    
    return Obx(() {
      if (!btController.isConnected.value) {
        return IconButton(
          icon: Icon(Icons.refresh),
          onPressed: () {
            btController.startScan();
            sessionService.extendSession();
          },
          tooltip: "ค้นหาอุปกรณ์ Bluetooth",
        );
      }
      return SizedBox.shrink();
    });
  }

  void _showSessionDialog() {
    final sessionService = Get.find<SessionService>();

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text("การจัดการเซสชัน"),
          ],
        ),
        content: Obx(() => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "เวลาที่เหลือ: ${sessionService.formattedRemainingTime}",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: sessionService.remainingTime.value <= 60
                    ? Colors.red[600]
                    : Colors.green[600],
              ),
            ),
            SizedBox(height: 16),
            Text(
              "คุณจะถูกออกจากระบบอัตโนมัติเมื่อหมดเวลา\nกดปุ่มด้านล่างเพื่อต่ออายุการใช้งาน",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text("ปิด"),
          ),
          ElevatedButton(
            onPressed: () {
              authController.extendUserSession();
              Get.back();
            },
            child: Text("ต่ออายุ 3 นาที"),
          ),
        ],
      ),
    );
  }
}
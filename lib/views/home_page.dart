import 'package:e_hong_app/services/system_check_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/bluetooth_controller.dart';
import '../services/timestamp_service.dart';
import '../services/session_service.dart';
import '../models/timestamp_model.dart';
import '../widgets/device_tile.dart';

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
    final SystemCheckService systemCheck = Get.find<SystemCheckService>();

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            authController.currentUser.value != null
                ? "สวัสดี ${authController.currentUser.value!.employeeNo}"
                : "หน้าหลัก",
          ),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        actions: [
          // แสดงเวลาที่เหลือ
          Obx(
            () => Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    // แสดง dialog สำหรับ extend session
                    _showSessionDialog();
                  },
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
            ),
          ),

          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authController.logout(),
            tooltip: "ออกจากระบบ",
          ),
          if (!btController.isConnected.value)
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                btController.startScan();
                // Extend session เมื่อมีการใช้งาน
                sessionService.extendSession();
              },
              tooltip: "ค้นหาอุปกรณ์ Bluetooth",
            ),
        ],
      ),
      body: GestureDetector(
        // Extend session เมื่อมีการแตะหน้าจอ
        onTap: () => sessionService.extendSession(),
        child: Obx(() {
          final user = authController.currentUser.value;
          if (user == null) {
            return Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // User Info Section
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getBackgroundColors(btController),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        _getStatusIcon(btController),
                        size: 50,
                        color: _getIconColor(btController),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      "พนักงาน: ${user.employeeNo}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "บริษัท: ${user.company}",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                    SizedBox(height: 12),
                    // แสดงสถานะ Bluetooth
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(btController),
                            size: 16,
                            color: Colors.white,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _getStatusText(btController),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),

              // Content Section
              Expanded(child: _buildBluetoothTab(btController)),
            ],
          );
        }),
      ),
    );
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
        content: Obx(
          () => Column(
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
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text("ปิด")),
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

  Widget _buildBluetoothTab(BluetoothController btController) {
    final sessionService = Get.find<SessionService>();

    return Obx(() {
      if (btController.isConnecting.value) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("🔄 กำลังเชื่อมต่ออุปกรณ์ล่าสุด..."),
            ],
          ),
        );
      }

      if (btController.isConnected.value) {
        return Center(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Obx(
                  () => AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    width: 200,
                    height: 200,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: btController.canActivate.value
                            ? () {
                                btController.activateNow();
                                sessionService.extendSession();
                              }
                            : null,
                        borderRadius: BorderRadius.circular(70),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: btController.canActivate.value
                                ? Colors.orange
                                : Colors.grey,
                            boxShadow: btController.canActivate.value
                                ? [
                                    BoxShadow(
                                      color: Colors.orange.withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.flash_on,
                                size: 40,
                                color: Colors.white,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Activate\nNow",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20),

                // Disconnect Button
                TextButton.icon(
                  onPressed: () {
                    btController.disconnect();
                    sessionService
                        .extendSession(); // Extend session เมื่อใช้งาน
                  },
                  icon: Icon(Icons.bluetooth_disabled, color: Colors.red),
                  label: Text(
                    "ตัดการเชื่อมต่อ",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Show device list when not connected
        return Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: btController.isConnecting.value
                    ? Colors.orange.withOpacity(0.1)
                    : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: btController.isConnecting.value
                      ? Colors.orange.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  btController.isConnecting.value
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange,
                            ),
                          ),
                        )
                      : Icon(Icons.bluetooth_searching, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      btController.isConnecting.value
                          ? "🔄 กำลังค้นหาอุปกรณ์..."
                          : "🔍 ค้นหาอุปกรณ์ Bluetooth",
                      style: TextStyle(
                        color: btController.isConnecting.value
                            ? Colors.orange[700]
                            : Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!btController.isConnecting.value)
                    IconButton(
                      onPressed: () {
                        btController.startScan();
                        sessionService
                            .extendSession(); // Extend session เมื่อใช้งาน
                      },
                      icon: Icon(Icons.refresh, color: Colors.blue),
                      tooltip: "รีเฟรช",
                    ),
                ],
              ),
            ),
            Expanded(
              child: btController.devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            btController.isConnecting.value
                                ? Icons.bluetooth_searching
                                : Icons.bluetooth_disabled,
                            size: 48,
                            color: btController.isConnecting.value
                                ? Colors.orange
                                : Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            btController.isConnecting.value
                                ? "กำลังค้นหา..."
                                : "ไม่พบอุปกรณ์",
                            style: TextStyle(
                              fontSize: 16,
                              color: btController.isConnecting.value
                                  ? Colors.orange[600]
                                  : Colors.grey[600],
                            ),
                          ),
                          if (!btController.isConnecting.value) ...[
                            SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: () {
                                btController.startScan();
                                sessionService
                                    .extendSession(); // Extend session เมื่อใช้งาน
                              },
                              icon: Icon(Icons.refresh),
                              label: Text("ค้นหาใหม่"),
                            ),
                          ],
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: btController.devices.length,
                      itemBuilder: (context, index) {
                        final device = btController.devices[index];
                        return GestureDetector(
                          onTap: () {
                            sessionService
                                .extendSession(); // Extend session เมื่อใช้งาน
                          },
                          child: DeviceTile(
                            device: device,
                            onTap: () {
                              btController.connectToDevice(device);
                              sessionService
                                  .extendSession(); // Extend session เมื่อใช้งาน
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      }
    });
  }

  IconData _getStatusIcon(BluetoothController btController) {
    if (btController.canActivate.value) {
      return Icons.bluetooth_connected;
    } else if (btController.isConnected.value) {
      return Icons.bluetooth;
    } else if (btController.isConnecting.value) {
      return Icons.bluetooth_searching;
    } else {
      return Icons.bluetooth_disabled;
    }
  }

  List<Color> _getBackgroundColors(BluetoothController btController) {
    if (btController.canActivate.value) {
      // เชื่อมต่อแล้วและพร้อม Activate - สีเขียว
      return [Colors.green[600]!, Colors.green[800]!];
    } else if (btController.isConnected.value) {
      // เชื่อมต่อแล้วแต่ยังไม่พร้อม Activate - สีส้ม
      return [Colors.orange[600]!, Colors.orange[800]!];
    } else if (btController.isConnecting.value) {
      // กำลังเชื่อมต่อ - สีน้ำเงิน
      return [Colors.blue[600]!, Colors.blue[800]!];
    } else {
      // ไม่ได้เชื่อมต่อ - สีเทา
      return [Colors.grey[600]!, Colors.grey[800]!];
    }
  }

  Color _getIconColor(BluetoothController btController) {
    if (btController.canActivate.value) {
      return Colors.green[600]!;
    } else if (btController.isConnected.value) {
      return Colors.orange[600]!;
    } else if (btController.isConnecting.value) {
      return Colors.blue[600]!;
    } else {
      return Colors.grey[600]!;
    }
  }

  String _getStatusText(BluetoothController btController) {
    if (btController.canActivate.value) {
      return "🟢 พร้อมใช้งาน";
    } else if (btController.isConnected.value) {
      return "🟡 เชื่อมต่อแล้ว";
    } else if (btController.isConnecting.value) {
      return "🔵 กำลังค้นหา...";
    } else {
      return "🔴 ไม่ได้เชื่อมต่อ";
    }
  }
}

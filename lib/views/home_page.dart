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
    final TimestampService timestampService = TimestampService();

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
                    colors: [Colors.blue[600]!, Colors.blue[800]!],
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.blue[600],
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
                    SizedBox(height: 20),

                    // Manual Time Stamp Button
                    Container(
                      width: double.infinity,
                      child: Obx(
                        () => ElevatedButton.icon(
                          onPressed: btController.canActivate.value
                              ? () {
                                  btController.activateNow();
                                  sessionService.extendSession();
                                }
                              : () {
                                  btController.startScan();
                                  sessionService.extendSession();
                                },
                          icon: btController.isConnected.value
                              ? (authController.isLoading.value
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.green[600]!,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.bluetooth_connected,
                                        color: Colors.green[600],
                                      ))
                              : (btController.isConnecting.value
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.orange[600]!,
                                              ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.bluetooth_disabled,
                                        color: Colors.red[600],
                                      )),
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                btController.isConnected.value
                                    ? (authController.isLoading.value
                                          ? "กำลังบันทึกเวลา..."
                                          : "🔗 เชื่อมต่อแล้ว - บันทึกเวลา")
                                    : (btController.isConnecting.value
                                          ? "🔄 กำลังค้นหาอุปกรณ์..."
                                          : "📱 ไม่ได้เชื่อมต่อ - แตะเพื่อค้นหา"),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: btController.isConnected.value
                                      ? Colors.green[600]
                                      : (btController.isConnecting.value
                                            ? Colors.orange[600]
                                            : Colors.red[600]),
                                ),
                              ),
                              if (btController.isConnected.value &&
                                  btController.selectedDevice.value != null)
                                Text(
                                  btController
                                              .selectedDevice
                                              .value
                                              ?.name
                                              ?.isNotEmpty ==
                                          true
                                      ? "อุปกรณ์: ${btController.selectedDevice.value!.name}"
                                      : "อุปกรณ์: ${btController.selectedDevice.value!.address}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[500],
                                  ),
                                ),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: btController.isConnected.value
                                ? Colors.green[50]
                                : (btController.isConnecting.value
                                      ? Colors.orange[50]
                                      : Colors.red[50]),
                            foregroundColor: btController.isConnected.value
                                ? Colors.green[600]
                                : (btController.isConnecting.value
                                      ? Colors.orange[600]
                                      : Colors.red[600]),
                            padding: EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: btController.isConnected.value
                                    ? Colors.green[300]!
                                    : (btController.isConnecting.value
                                          ? Colors.orange[300]!
                                          : Colors.red[300]!),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // System Status Section
              _buildSystemStatusSection(),

              // Content Section
              Expanded(
                child: DefaultTabController(
                  length: 2,
                  child: Column(
                    children: [
                      TabBar(
                        onTap: (index) {
                          // Extend session เมื่อเปลี่ยน tab
                          sessionService.extendSession();
                        },
                        tabs: [
                          Tab(
                            icon: Icon(Icons.history),
                            text: "ประวัติการลงเวลา",
                          ),
                          Tab(icon: Icon(Icons.bluetooth), text: "Bluetooth"),
                        ],
                        labelColor: Colors.blue[600],
                        unselectedLabelColor: Colors.grey[600],
                        indicatorColor: Colors.blue[600],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Timestamp History Tab
                            _buildTimestampHistoryTab(
                              timestampService,
                              user.id!,
                            ),

                            // Bluetooth Tab
                            _buildBluetoothTab(btController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSystemStatusSection() {
    final SystemCheckService systemCheck = Get.find<SystemCheckService>();

    return Obx(
      () => Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: systemCheck.isSystemReady.value
              ? Colors.green.withOpacity(0.1)
              : Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: systemCheck.isSystemReady.value
                ? Colors.green.withOpacity(0.3)
                : Colors.red.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  systemCheck.isSystemReady.value
                      ? Icons.check_circle
                      : Icons.warning,
                  color: systemCheck.isSystemReady.value
                      ? Colors.green[600]
                      : Colors.red[600],
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    systemCheck.isSystemReady.value
                        ? "✅ ระบบพร้อมใช้งาน"
                        : "⚠️ ระบบไม่พร้อม",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: systemCheck.isSystemReady.value
                          ? Colors.green[700]
                          : Colors.red[700],
                    ),
                  ),
                ),
                if (!systemCheck.isSystemReady.value)
                  TextButton(
                    onPressed: () async {
                      await systemCheck.ensureSystemReady();
                    },
                    child: Text("แก้ไข"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[600],
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12),

            // Bluetooth Status
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: systemCheck.isBluetoothEnabled.value
                      ? Colors.blue[600]
                      : Colors.grey[400],
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    systemCheck.isBluetoothEnabled.value
                        ? "🔵 Bluetooth: เปิด"
                        : "🔵 Bluetooth: ปิด",
                    style: TextStyle(
                      color: systemCheck.isBluetoothEnabled.value
                          ? Colors.blue[600]
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (!systemCheck.isBluetoothEnabled.value)
                  IconButton(
                    onPressed: () => systemCheck.enableBluetooth(),
                    icon: Icon(Icons.settings, color: Colors.blue[600]),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),

            SizedBox(height: 8),

            // GPS Status
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: systemCheck.isLocationEnabled.value
                      ? Colors.red[600]
                      : Colors.grey[400],
                  size: 20,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    systemCheck.isLocationEnabled.value
                        ? "📍 GPS: เปิด"
                        : "📍 GPS: ปิด",
                    style: TextStyle(
                      color: systemCheck.isLocationEnabled.value
                          ? Colors.red[600]
                          : Colors.grey[600],
                    ),
                  ),
                ),
                if (!systemCheck.isLocationEnabled.value)
                  IconButton(
                    onPressed: () => systemCheck.enableLocation(),
                    icon: Icon(Icons.settings, color: Colors.red[600]),
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
              ],
            ),

            if (!systemCheck.isSystemReady.value) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.orange[700], size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "กรุณาเปิด Bluetooth และ GPS เพื่อใช้งานระบบ",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

  // เพิ่ม methods อื่นๆ เหมือนเดิม...
  Widget _buildTimestampHistoryTab(
    TimestampService timestampService,
    String userId,
  ) {
    final sessionService = Get.find<SessionService>();

    return RefreshIndicator(
      onRefresh: () async {
        // Extend session เมื่อ pull to refresh
        sessionService.extendSession();
        await Future.delayed(Duration(milliseconds: 500));
      },
      child: StreamBuilder<List<TimestampModel>>(
        stream: timestampService.getTimestamps(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print("Error loading timestamps: ${snapshot.error}");
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  SizedBox(height: 16),
                  Text(
                    "เกิดข้อผิดพลาดในการโหลดข้อมูล",
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final timestamps = snapshot.data ?? [];

          if (timestamps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text(
                    "ยังไม่มีประวัติการลงเวลา",
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: timestamps.length,
            itemBuilder: (context, index) {
              final timestamp = timestamps[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.access_time,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatDateTime(timestamp.timestamp),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  _formatTime(timestamp.timestamp),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: Colors.red[500],
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "ละติจูด: ${timestamp.latitude.toStringAsFixed(6)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    "ลองจิจูด: ${timestamp.longitude.toStringAsFixed(6)}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  if (timestamp.accuracy != null)
                                    Text(
                                      "ความแม่นยำ: ${timestamp.accuracy!.toStringAsFixed(1)} เมตร",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
                // Connection Status
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.bluetooth_connected,
                        color: Colors.green,
                        size: 32,
                      ),
                      SizedBox(height: 8),
                      Text(
                        btController.selectedDevice.value?.name?.isNotEmpty ==
                                true
                            ? "✅ เชื่อมต่อกับ: ${btController.selectedDevice.value!.name}"
                            : "✅ เชื่อมต่อกับ: ${btController.selectedDevice.value?.address ?? 'อุปกรณ์'}",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30),

                Container(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: btController.canActivate.value
                        ? () {
                            btController.activateNow();
                            sessionService.extendSession();
                          }
                        : null,
                    icon: Icon(Icons.flash_on),
                    label: Text(
                      "⚡ Activate Now",
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: btController.canActivate.value
                          ? Colors.orange
                          : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.day}/${dateTime.month}/${dateTime.year}";
  }

  String _formatTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
  }
}

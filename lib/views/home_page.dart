import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';
import '../controllers/bluetooth_controller.dart';
import '../widgets/device_tile.dart';

class HomePage extends StatelessWidget {
  final AuthController authController = Get.find();

  @override
  Widget build(BuildContext context) {
    final BluetoothController btController = Get.find<BluetoothController>();
    return Scaffold(
      appBar: AppBar(
        title: Text("Bluetooth เชื่อมต่อ"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () => authController.logout(),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: btController.startScan,
          ),
        ],
      ),
      body: Obx(() {
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
                  // แสดงสถานะการเชื่อมต่อ
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.bluetooth_connected, 
                             color: Colors.green, size: 32),
                        SizedBox(height: 8),
                        Text(
                          btController.selectedDevice.value?.name?.isNotEmpty == true
                              ? "✅ เชื่อมต่อกับ: ${btController.selectedDevice.value!.name}"
                              : "✅ เชื่อมต่อกับ: ${btController.selectedDevice.value?.address ?? 'อุปกรณ์'}",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          "สถานะ: ${btController.bluetoothService.connection?.isConnected == true ? 'เชื่อมต่อแล้ว' : 'ไม่ได้เชื่อมต่อ'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: btController.bluetoothService.connection?.isConnected == true 
                                ? Colors.green[600] 
                                : Colors.red[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // ขั้นตอนที่ 1: Connect
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: btController.isConnectResponseReceived.value 
                          ? null 
                          : btController.activateConnect,
                      icon: Icon(btController.isConnectResponseReceived.value 
                          ? Icons.check_circle 
                          : Icons.electrical_services),
                      label: Text(
                        btController.isConnectResponseReceived.value 
                            ? "🔌 Connect สำเร็จแล้ว" 
                            : "🔌 Activate Connect",
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btController.isConnectResponseReceived.value 
                            ? Colors.green 
                            : Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 15),
                  
                  // แสดงสถานะการรอ response
                  if (!btController.isConnectResponseReceived.value && 
                      btController.isConnected.value)
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "รอการตอบกลับจากอุปกรณ์...",
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: 15),
                  
                  // ขั้นตอนที่ 2: Activate Now
                  Container(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: btController.canActivate.value 
                          ? btController.activateNow 
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
                  
                  // คำแนะนำ
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "📋 ขั้นตอนการใช้งาน:",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "1. กด 'Activate Connect' เพื่อส่งคำสั่งเชื่อมต่อ\n"
                          "2. รอให้อุปกรณ์ตอบกลับ (ปุ่มจะเปลี่ยนสี)\n"
                          "3. กด 'Activate Now' เพื่อเปิดใช้งาน",
                          style: TextStyle(
                            color: Colors.blue[600],
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 20),
                  
                  // ปุ่มตัดการเชื่อมต่อ
                  TextButton.icon(
                    onPressed: btController.disconnect,
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
          // แสดงรายการอุปกรณ์เมื่อยังไม่ได้เชื่อมต่อ
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
                        : Colors.blue.withOpacity(0.3)
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
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            ),
                          )
                        : Icon(Icons.bluetooth_searching, color: Colors.blue),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        btController.isConnecting.value
                            ? "🔄 กำลังค้นหาอุปกรณ์..."
                            : "🔍 ค้นหาอุปกรณ์ Bluetooth ใกล้เคียง",
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
                        onPressed: btController.startScan,
                        icon: Icon(Icons.refresh, color: Colors.blue),
                        tooltip: "รีเฟรช",
                      ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    // เรียกฟังก์ชันสแกนใหม่
                    btController.startScan();
                    // รอสักครู่เพื่อให้การสแกนเริ่มต้น
                    await Future.delayed(Duration(milliseconds: 500));
                  },
                  color: Colors.blue,
                  backgroundColor: Colors.white,
                  child: btController.devices.isEmpty
                      ? SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Container(
                            height: MediaQuery.of(context).size.height * 0.6,
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
                                  SizedBox(height: 8),
                                  Text(
                                    "ลากลงเพื่อรีเฟรช",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                  SizedBox(height: 16),
                                  TextButton.icon(
                                    onPressed: btController.startScan,
                                    icon: Icon(Icons.refresh),
                                    label: Text("ค้นหาใหม่"),
                                  ),
                                ],
                                if (btController.isConnecting.value) ...[
                                  SizedBox(height: 8),
                                  Text(
                                    "กรุณารอสักครู่...",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          physics: AlwaysScrollableScrollPhysics(),
                          itemCount: btController.devices.length,
                          itemBuilder: (context, index) {
                            final device = btController.devices[index];
                            return DeviceTile(
                              device: device,
                              onTap: () => btController.connectToDevice(device),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
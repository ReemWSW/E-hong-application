// lib/widgets/bluetooth_tab.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';
import '../services/session_service.dart';
import '../widgets/device_tile.dart';


class BluetoothTab extends StatelessWidget {
  final BluetoothController btController;

  const BluetoothTab({
    super.key,
    required this.btController,
  });

  @override
  Widget build(BuildContext context) {
    final sessionService = Get.find<SessionService>();

    return Obx(() {
      if (btController.isConnecting.value) {
        return _buildConnectingView();
      }

      if (btController.isConnected.value) {
        return _buildConnectedView(sessionService);
      } else {
        return _buildDeviceListView(sessionService);
      }
    });
  }

  // เหมือนเดิม...
  Widget _buildConnectingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("🔄 กำลังค้นหาอุปกรณ์..."),
        ],
      ),
    );
  }

  Widget _buildConnectedView(SessionService sessionService) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActivateButton(sessionService),
            SizedBox(height: 20),
            _buildDisconnectButton(sessionService),
          ],
        ),
      ),
    );
  }

  Widget _buildActivateButton(SessionService sessionService) {
    return Obx(() => AnimatedContainer(
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
          borderRadius: BorderRadius.circular(100),
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
    ));
  }

  Widget _buildDisconnectButton(SessionService sessionService) {
    return TextButton.icon(
      onPressed: () {
        btController.disconnect();
        sessionService.extendSession();
      },
      icon: Icon(Icons.bluetooth_disabled, color: Colors.red),
      label: Text(
        "ตัดการเชื่อมต่อ",
        style: TextStyle(color: Colors.red),
      ),
    );
  }

  Widget _buildDeviceListView(SessionService sessionService) {
    return Column(
      children: [
        // ถ้ายังไม่เริ่มค้นหาและไม่มีอุปกรณ์ ให้แสดงปุ่มเริ่มค้นหา
        if (btController.devices.isEmpty && !btController.isConnecting.value)
          _buildStartScanButton(sessionService)
        else
          _buildSearchHeader(sessionService),
        
        Expanded(
          child: btController.devices.isEmpty
              ? _buildEmptyDeviceList(sessionService)
              : _buildDeviceList(sessionService),
        ),
      ],
    );
  }

  // เพิ่ม widget สำหรับปุ่มเริ่มค้นหา
  Widget _buildStartScanButton(SessionService sessionService) {
    return Container(
      margin: EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: Colors.blue[600],
          ),
          SizedBox(height: 20),
          Text(
            "ค้นหาอุปกรณ์ Bluetooth",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            "กดปุ่มด้านล่างเพื่อเริ่มค้นหาอุปกรณ์ที่ใกล้เคียง",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                btController.startScan();
                sessionService.extendSession();
              },
              icon: Icon(Icons.search),
              label: Text(
                "เริ่มค้นหาอุปกรณ์",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchHeader(SessionService sessionService) {
    return Container(
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
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
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
                sessionService.extendSession();
              },
              icon: Icon(Icons.refresh, color: Colors.blue),
              tooltip: "รีเฟรช",
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeviceList(SessionService sessionService) {
    return Center(
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
                sessionService.extendSession();
              },
              icon: Icon(Icons.refresh),
              label: Text("ค้นหาใหม่"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceList(SessionService sessionService) {
    return ListView.builder(
      itemCount: btController.devices.length,
      itemBuilder: (context, index) {
        final device = btController.devices[index];
        return GestureDetector(
          onTap: () => sessionService.extendSession(),
          child: DeviceTile(
            device: device,
            onTap: () {
              btController.connectToDevice(device);
              sessionService.extendSession();
            },
          ),
        );
      },
    );
  }
}
// lib/widgets/bluetooth_tab.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';
import '../services/session_service.dart';
import '../widgets/device_tile.dart';

class BluetoothTab extends StatelessWidget {
  final BluetoothController btController;

  const BluetoothTab({super.key, required this.btController});

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
    return Obx(
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
                  Icon(Icons.flash_on, size: 40, color: Colors.white),
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
    );
  }

  Widget _buildDisconnectButton(SessionService sessionService) {
    return TextButton.icon(
      onPressed: () {
        btController.disconnect();
        sessionService.extendSession();
      },
      icon: Icon(Icons.bluetooth_disabled, color: Colors.red),
      label: Text("ตัดการเชื่อมต่อ", style: TextStyle(color: Colors.red)),
    );
  }

  Widget _buildDeviceListView(SessionService sessionService) {
    return RefreshIndicator(
      onRefresh: () async {
        sessionService.extendSession();
        await btController.startScan();
      },
      child: btController.devices.isEmpty
          ? _buildEmptyDeviceList(sessionService)
          : _buildDeviceList(sessionService),
    );
  }

  Widget _buildEmptyDeviceList(SessionService sessionService) {
    return ListView(
      physics: AlwaysScrollableScrollPhysics(), // ให้สามารถดึงได้แม้ไม่มีข้อมูล
      children: [
        SizedBox(height: 100),
        Icon(
          btController.isConnecting.value
              ? Icons.bluetooth_searching
              : Icons.bluetooth_disabled,
          size: 48,
          color: btController.isConnecting.value ? Colors.orange : Colors.grey,
        ),
        SizedBox(height: 16),
        Center(
          child: Text(
            btController.isConnecting.value ? "กำลังค้นหา..." : "ไม่พบอุปกรณ์",
            style: TextStyle(
              fontSize: 16,
              color: btController.isConnecting.value
                  ? Colors.orange[600]
                  : Colors.grey[600],
            ),
          ),
        ),
        if (!btController.isConnecting.value) SizedBox(height: 16),
        if (!btController.isConnecting.value)
          Center(
            child: TextButton.icon(
              onPressed: () {
                btController.startScan();
                sessionService.extendSession();
              },
              icon: Icon(Icons.refresh),
              label: Text("ค้นหาใหม่"),
            ),
          ),
      ],
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

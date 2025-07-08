// lib/widgets/user_info_section.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/user_model.dart';
import '../controllers/bluetooth_controller.dart';

class UserInfoSection extends StatelessWidget {
  final EhongUserModel user;
  final BluetoothController btController;

  const UserInfoSection({
    super.key,
    required this.user,
    required this.btController,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _getBackgroundColors(),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.white,
            child: Icon(
              _getStatusIcon(),
              size: 50,
              color: _getIconColor(),
            ),
          ),
          SizedBox(height: 16),
          Text(
            "พนักงาน: ${user.fullName}",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
         
          SizedBox(height: 12),
          // แสดงสถานะ Bluetooth
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getStatusIcon(),
                  size: 16,
                  color: Colors.white,
                ),
                SizedBox(width: 6),
                Text(
                  _getStatusText(),
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
    ));
  }

  List<Color> _getBackgroundColors() {
    if (btController.canActivate.value) {
      return [Colors.green[600]!, Colors.green[800]!];
    } else if (btController.isConnected.value) {
      return [Colors.orange[600]!, Colors.orange[800]!];
    } else if (btController.isConnecting.value) {
      return [Colors.blue[600]!, Colors.blue[800]!];
    } else {
      return [Colors.grey[600]!, Colors.grey[800]!];
    }
  }

  IconData _getStatusIcon() {
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

  Color _getIconColor() {
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

  String _getStatusText() {
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
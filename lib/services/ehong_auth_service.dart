import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class EhongAuthService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.ehongmd.com',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'Content-Type': 'application/json',
    },
  ));

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login',
        data: {
          "Username": username,
          "Password": password,
        },
      );

      if (response.statusCode == 200) {
        final dataList = response.data as List<dynamic>;

        if (dataList.isEmpty) {
          throw 'ไม่พบข้อมูลผู้ใช้';
        }

        final data = dataList.first;

        if (data['status'] != 'success') {
          throw 'เข้าสู่ระบบไม่สำเร็จ: ${data['status']}';
        }

        return data;
      } else {
        throw 'เซิร์ฟเวอร์ตอบกลับ ${response.statusCode}';
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout) {
        throw 'การเชื่อมต่อหมดเวลา';
      } else if (e.response != null) {
        switch (e.response?.statusCode) {
          case 401:
               throw 'กรุณาตรวจสอบชื่อผู้ใช้และรหัสผ่าน';
            case 404:
              throw 'ไม่พบ URL ที่ร้องขอ';
          default:
        }
        if (kDebugMode) {
          print('Dio error: ${e.response?.data}');
        }
        throw 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
      } else {
        if (kDebugMode) {
          print('Dio error: $e');
        }
        throw 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
      }
    } catch (e) {
      throw 'ไม่สามารถเข้าสู่ระบบได้: $e';
    }
  }
}

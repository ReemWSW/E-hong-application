// lib/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class UserModel {
  final String? id;
  final String employeeNo;
  final String? employeeName;
  final String company;
  final String passwordHash; // เก็บ password ที่เข้ารหัสแล้ว
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    this.id,
    required this.employeeNo,
    required this.company,
    required this.passwordHash,
    this.employeeName,
    this.createdAt,
    this.lastLogin,
  });

  // สร้าง hash จาก password
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      employeeNo: map['employeeNo'] ?? '',
      employeeName: map['employeeName'], 
      company: map['company'] ?? '',
      passwordHash: map['passwordHash'] ?? '',
      createdAt: map['createdAt']?.toDate(),
      lastLogin: map['lastLogin']?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeNo': employeeNo,
      'employeeName': employeeName,
      'company': company,
      'passwordHash': passwordHash,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
    };
  }

  factory UserModel.create({
    required String employeeNo,
    required String employeeName,
    required String password,
    required String company,
  }) {
    return UserModel(
      employeeNo: employeeNo,
      employeeName: employeeName,
      company: company,
      passwordHash: hashPassword(password),
      createdAt: DateTime.now(),
    );
  }

  // ตรวจสอบ password
  bool verifyPassword(String password) {
    return passwordHash == hashPassword(password);
  }

  UserModel copyWithLastLogin() {
    return UserModel(
      id: id,
      employeeNo: employeeNo,
      employeeName: employeeName,
      company: company,
      passwordHash: passwordHash,
      createdAt: createdAt,
      lastLogin: DateTime.now(),
    );
  }
}
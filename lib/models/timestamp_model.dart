// lib/models/timestamp_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TimestampModel {
  final String? id;
  final String userId;
  final String employeeNo;
  final String company;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final String? address;

  TimestampModel({
    this.id,
    required this.userId,
    required this.employeeNo,
    required this.company,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.address,
  });

  factory TimestampModel.fromMap(Map<String, dynamic> map, String id) {
    return TimestampModel(
      id: id,
      userId: map['userId'] ?? '',
      employeeNo: map['employeeNo'] ?? '',
      company: map['company'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      accuracy: map['accuracy']?.toDouble(),
      address: map['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'employeeNo': employeeNo,
      'company': company,
      'timestamp': Timestamp.fromDate(timestamp),
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'address': address,
    };
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ExpireCheckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> checkExpiration() async {
    try {
      final snapshot = await _firestore.collection('expire').get();
      
      if (snapshot.docs.isEmpty) {
        if (kDebugMode) {
          print('No expire documents found');
        }
        return true; // Allow if no expire date is set
      }

      final now = DateTime.now();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final expirationTimestamp = data['expirationDate'] as Timestamp?;
        
        if (expirationTimestamp == null) {
          if (kDebugMode) {
            print('No expirationDate found in document: ${doc.id}');
          }
          continue; // Skip this document if no expiration date
        }
        
        final expireDate = expirationTimestamp.toDate();
        if (now.isAfter(expireDate)) {
          if (kDebugMode) {
            print('App is expired. Current: $now, Expire: $expireDate');
          }
          return false; // App is expired
        }
      }
      
      return true; // App is not expired
    } catch (e) {
      if (kDebugMode) {
        print('Error checking expiration: $e');
      }
      return true; // Allow access if there's an error
    }
  }
}
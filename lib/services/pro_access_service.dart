import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/upgrade_screen.dart';
import 'firebase_bootstrap.dart';

class ProAccessService {
  ProAccessService._();

  static Future<bool> hasPro() async {
    if (!FirebaseBootstrap.isInitialized) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('proEntitlements')
          .doc(user.uid)
          .get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null || data['active'] != true) return false;

      final expiresAt = data['expiresAt'];
      if (data['type'] == 'lifetime' && expiresAt == null) return true;
      if (expiresAt is Timestamp) {
        return expiresAt.toDate().isAfter(DateTime.now());
      }
      return false;
    } catch (_) {
      // Never grant paid access when the server entitlement cannot be verified.
      return false;
    }
  }

  static Future<bool> requirePro(
    BuildContext context, {
    required String feature,
  }) async {
    if (await hasPro()) return true;
    if (!context.mounted) return false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => UpgradeScreen(requiredFeature: feature),
      ),
    );
    return hasPro();
  }
}

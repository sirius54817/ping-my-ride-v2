import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import '../models/trip_qr.dart';
import '../models/booking.dart';
import 'fcm_service.dart';

class TripQRService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<TripQR> _driverTripQRs = [];
  bool _isLoading = false;

  List<TripQR> get driverTripQRs => _driverTripQRs;
  bool get isLoading => _isLoading;

  /// Generate a unique QR code for a trip
  String _generateTripQRCode(String busId, String routeId, DateTime travelDate, String timeSlot) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final dateStr = travelDate.toIso8601String().split('T')[0];
    final data = '$busId|$routeId|$dateStr|$timeSlot|$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return 'TRIP_${digest.toString()}';
  }

  /// Driver creates a QR code for their trip
  Future<TripQR?> generateTripQR({
    required String busId,
    required String busNumber,
    required String routeId,
    required String routeName,
    required DateTime travelDate,
    required String timeSlot,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Check if QR already exists for this trip
      final existing = await _firestore
          .collection('trip_qrs')
          .where('busId', isEqualTo: busId)
          .where('routeId', isEqualTo: routeId)
          .where('timeSlot', isEqualTo: timeSlot)
          .get();

      for (var doc in existing.docs) {
        final tripQR = TripQR.fromMap(doc.data(), doc.id);
        final tripDate = DateTime(
          tripQR.travelDate.year,
          tripQR.travelDate.month,
          tripQR.travelDate.day,
        );
        final targetDate = DateTime(
          travelDate.year,
          travelDate.month,
          travelDate.day,
        );
        
        if (tripDate.isAtSameMomentAs(targetDate) && tripQR.isActive) {
          return tripQR;
        }
      }

      // Generate unique QR code
      final qrCode = _generateTripQRCode(busId, routeId, travelDate, timeSlot);

      // Get driver name from bus collection or auth
      String driverName = user.displayName ?? user.email?.split('@')[0] ?? 'Driver';

      // Set expiration time (e.g., 2 hours after trip time)
      final expiresAt = travelDate.add(const Duration(hours: 2));

      final tripQR = TripQR(
        id: '',
        busId: busId,
        busNumber: busNumber,
        driverId: user.uid,
        driverName: driverName,
        routeId: routeId,
        routeName: routeName,
        travelDate: travelDate,
        timeSlot: timeSlot,
        qrCode: qrCode,
        createdAt: DateTime.now(),
        expiresAt: expiresAt,
      );

      // Save to Firestore
      final docRef = await _firestore.collection('trip_qrs').add(tripQR.toMap());
      // Notify students that the trip has started
      await FCMService().notifyStudentsOfTripStart(
        busId: busId,
        routeId: routeId,
        timeSlot: timeSlot,
        busNumber: busNumber,
        routeName: routeName,
        driverName: driverName,
        travelDate: travelDate,
      );

      await fetchDriverTripQRs();
      return tripQR.copyWith(id: docRef.id);
    } catch (e) {
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch driver's trip QRs
  Future<void> fetchDriverTripQRs() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _driverTripQRs = [];
        notifyListeners();
        return;
      }

      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('trip_qrs')
          .where('driverId', isEqualTo: user.uid)
          .get();

      _driverTripQRs = snapshot.docs
          .map((doc) => TripQR.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by travel date (most recent first)
      _driverTripQRs.sort((a, b) => b.travelDate.compareTo(a.travelDate));
    } catch (e) {
      _driverTripQRs = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Student scans driver's QR code to mark ride as started
  Future<Map<String, dynamic>> scanTripQR(String qrCode, Booking booking) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Student not authenticated',
        };
      }

      // Find trip QR with this code
      final snapshot = await _firestore
          .collection('trip_qrs')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Invalid QR code',
        };
      }

      final tripQRDoc = snapshot.docs.first;
      final tripQR = TripQR.fromMap(tripQRDoc.data(), tripQRDoc.id);

      // Check if QR is expired
      if (tripQR.isExpired) {
        return {
          'success': false,
          'message': 'QR code has expired',
        };
      }

      // Check if QR is active
      if (!tripQR.isActive) {
        return {
          'success': false,
          'message': 'QR code is no longer active',
        };
      }

      // Verify the QR matches the student's booking
      if (tripQR.busId != booking.busId) {
        return {
          'success': false,
          'message': 'QR code is for a different bus',
        };
      }

      if (tripQR.routeId != booking.routeId) {
        return {
          'success': false,
          'message': 'QR code is for a different route',
        };
      }

      // Check if student already scanned this QR
      if (tripQR.scannedByUsers.contains(user.uid)) {
        return {
          'success': false,
          'message': 'You have already scanned this QR code',
        };
      }

      // Update trip QR with student scan
      await _firestore.collection('trip_qrs').doc(tripQRDoc.id).update({
        'scannedByUsers': FieldValue.arrayUnion([user.uid]),
      });

      // Update booking status to active/started
      await _firestore.collection('bookings').doc(booking.id).update({
        'status': 'active',
        'rideStartedAt': FieldValue.serverTimestamp(),
      });
      return {
        'success': true,
        'message': 'Ride started successfully!',
        'tripQR': tripQR,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error scanning QR code: $e',
      };
    }
  }

  /// Deactivate a trip QR (when trip is completed)
  Future<bool> deactivateTripQR(String tripQRId) async {
    try {
      await _firestore.collection('trip_qrs').doc(tripQRId).update({
        'isActive': false,
      });

      await fetchDriverTripQRs();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get trip QR by ID
  Future<TripQR?> getTripQRById(String tripQRId) async {
    try {
      final doc = await _firestore.collection('trip_qrs').doc(tripQRId).get();
      if (doc.exists) {
        return TripQR.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get active trip QRs for a driver
  List<TripQR> get activeTripQRs => _driverTripQRs
      .where((qr) => qr.isActive && !qr.isExpired)
      .toList();

  /// Stream trip QRs for a driver
  Stream<List<TripQR>> streamDriverTripQRs(String driverId) {
    return _firestore
        .collection('trip_qrs')
        .where('driverId', isEqualTo: driverId)
        .orderBy('travelDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TripQR.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream trip QR by ID
  Stream<TripQR?> streamTripQR(String tripQRId) {
    return _firestore
        .collection('trip_qrs')
        .doc(tripQRId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return TripQR.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }
}

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform;

/// Service to handle Firebase Cloud Messaging for push notifications
class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Request Android notification permission (API 33+)
  Future<bool> _requestAndroidNotificationPermission() async {
    try {
      // Only request for Android devices
      if (!kIsWeb && Platform.isAndroid) {
        final status = await Permission.notification.status;
        
        if (status.isGranted) {
          return true;
        }
        
        if (status.isDenied) {
          final result = await Permission.notification.request();
          
          if (result.isGranted) {
            return true;
          } else if (result.isDenied) {
            return false;
          } else if (result.isPermanentlyDenied) {
            return false;
          }
        }
        
        if (status.isPermanentlyDenied) {
          return false;
        }
      }
      
      // For iOS, web, and other platforms, return true
      return true;
    } catch (e) {
      // Continue without blocking even if permission check fails
      return false;
    }
  }

  /// Initialize FCM and request notification permissions
  Future<void> initialize() async {
    try {
      // First, request Android notification permission (API 33+)
      await _requestAndroidNotificationPermission();
      
      // Request permission for iOS and web
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _retrieveToken();
      } else {
      }

      // Listen to token refresh
      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _fcmToken = newToken;
      });
    } catch (e) {
    }
  }

  /// Retrieve the FCM token
  Future<String?> _retrieveToken() async {
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      return _fcmToken;
    } catch (e) {
      return null;
    }
  }

  /// Store FCM token in Firestore for the logged-in user
  Future<void> storeFCMToken(String userId, String userType) async {
    try {
      if (_fcmToken == null) {
        await _retrieveToken();
      }

      if (_fcmToken != null) {
        // Store token in the canonical user document.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
          'fcmToken': _fcmToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'fcmTokenUserType': userType.toLowerCase(),
        }, SetOptions(merge: true));
      } else {
      }
    } catch (e) {
    }
  }

  /// Remove FCM token from Firestore when user logs out
  Future<void> removeFCMToken(String userId, String userType) async {
    try {
      // Remove token from canonical user document.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
        'fcmTokenUserType': FieldValue.delete(),
      });
    } catch (e) {
    }
  }

  /// Setup foreground message handler
  void setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      try {
        if (message.notification != null) {
        }
      } catch (e) {
      }
    });
  }

  /// Setup background message handler
  static Future<void> handleBackgroundMessage(RemoteMessage message) async {
    try {
    } catch (e) {
      // Silently fail - don't crash the app
    }
  }

  /// Request permission after login (for better UX)
  Future<bool> requestPermissionAfterLogin() async {
    try {
      // First, request Android notification permission (API 33+)
      final androidPermissionGranted = await _requestAndroidNotificationPermission();
      
      // Request permission for iOS and web
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      bool isAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      // For Android, we need both permissions
      if (!kIsWeb && Platform.isAndroid) {
        isAuthorized = isAuthorized && androidPermissionGranted;
      }

      if (isAuthorized) {
        await _retrieveToken();
      } else {
      }

      return isAuthorized;
    } catch (e) {
      return false;
    }
  }

  /// Send trip start notification to students
  /// Creates notification records in Firestore for students to receive
  Future<void> notifyStudentsOfTripStart({
    required String busId,
    required String routeId,
    required String timeSlot,
    required String busNumber,
    required String routeName,
    required String driverName,
    required DateTime travelDate,
  }) async {
    try {
      final dayStart = DateTime(travelDate.year, travelDate.month, travelDate.day);
      final nextDay = dayStart.add(const Duration(days: 1));
      final dateStr = '${travelDate.year}-${travelDate.month.toString().padLeft(2, '0')}-${travelDate.day.toString().padLeft(2, '0')}';

      QuerySnapshot<Map<String, dynamic>> bookingsSnapshot;
      try {
        // Optimized query path: constrain date in Firestore when selectedBookingDate is indexed.
        bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('busId', isEqualTo: busId)
            .where('routeId', isEqualTo: routeId)
            .where('selectedTimeSlot', isEqualTo: timeSlot)
            .where('status', isEqualTo: 'confirmed')
            .where('selectedBookingDate', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
            .where('selectedBookingDate', isLessThan: Timestamp.fromDate(nextDay))
            .get();
      } on FirebaseException {
        // Backward-compatible fallback if required index/date field is unavailable.
        bookingsSnapshot = await FirebaseFirestore.instance
            .collection('bookings')
            .where('busId', isEqualTo: busId)
            .where('routeId', isEqualTo: routeId)
            .where('selectedTimeSlot', isEqualTo: timeSlot)
            .where('status', isEqualTo: 'confirmed')
            .get();
      }

      if (bookingsSnapshot.docs.isEmpty) {
        return;
      }

      final relevantBookings = bookingsSnapshot.docs.where((doc) {
        final bookingData = doc.data();
        final selectedDate = bookingData['selectedBookingDate'];
        if (selectedDate == null) return false;

        final bookingDate = (selectedDate as Timestamp).toDate();
        final bookingDateStr = '${bookingDate.year}-${bookingDate.month.toString().padLeft(2, '0')}-${bookingDate.day.toString().padLeft(2, '0')}';
        return bookingDateStr == dateStr;
      }).toList();

      // Create notification records for each student
      for (var bookingDoc in relevantBookings) {
        try {
          final userId = bookingDoc.data()['userId'];
          if (userId == null || userId.isEmpty) {
            continue;
          }

          // Get student's FCM token
          String? fcmToken;
          try {
            final studentDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .get();
            
            if (studentDoc.exists) {
              final studentData = studentDoc.data();
              if (studentData?['userType'] == 'student') {
                fcmToken = studentData?['fcmToken'];
              }
            }
          } catch (e) {
          }

          // Create notification record
          await FirebaseFirestore.instance
              .collection('notifications')
              .add({
            'userId': userId,
            'fcmToken': fcmToken, // Store token for backend processing
            'type': 'trip_started',
            'title': '🚌 Your Bus is on the way!',
            'body': '$driverName has started the $routeName route (Bus $busNumber) for $timeSlot.',
            'data': {
              'busId': busId,
              'busNumber': busNumber,
              'routeId': routeId,
              'routeName': routeName,
              'timeSlot': timeSlot,
              'driverName': driverName,
              'travelDate': dateStr,
            },
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });

        } catch (e) {
        }
      }
    } catch (e) {
    }
  }
}

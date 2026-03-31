import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

/// Service to listen for trip start notifications from Firestore
class NotificationListenerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  StreamSubscription<QuerySnapshot>? _notificationStream;
  String? _currentUserId;
  
  /// Start listening for notifications for the logged-in user
  Future<void> startListening(String userId) async {
    if (_currentUserId == userId && _notificationStream != null) {
      return;
    }
    
    // Stop existing stream if any
    await stopListening();
    
    _currentUserId = userId;
    // Listen to notifications created in the last 5 minutes that haven't been read
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    
    _notificationStream = _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinutesAgo))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) async {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            await _handleNotification(change.doc.id, data);
          }
        }
      }
    }, onError: (error) {
    });
  }
  
  /// Handle incoming notification
  Future<void> _handleNotification(String notificationId, Map<String, dynamic> data) async {
    try {
      final type = data['type'] as String?;
      final title = data['title'] as String?;
      final body = data['body'] as String?;
      
      if (type == null || title == null || body == null) {
        return;
      }
      // Show local notification based on type
      switch (type) {
        case 'trip_started':
          await _showTripStartedNotification(title, body, data['data']);
          break;
        default:
      }
      
      // Mark notification as read
      await _markAsRead(notificationId);
    } catch (e) {
    }
  }
  
  /// Show trip started notification
  Future<void> _showTripStartedNotification(
    String title,
    String body,
    dynamic notificationData,
  ) async {
    try {
      // Show local notification
      await _notificationService.showTripStartNotification(
        title: title,
        body: body,
      );
    } catch (e) {
    }
  }
  
  /// Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
    }
  }
  
  /// Stop listening for notifications
  Future<void> stopListening() async {
    await _notificationStream?.cancel();
    _notificationStream = null;
    _currentUserId = null;
  }
  
  /// Check if currently listening
  bool get isListening => _notificationStream != null;
}

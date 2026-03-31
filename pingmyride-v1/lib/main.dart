import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/bus_service.dart';
import 'core/services/trip_service.dart';
import 'core/services/theme_service.dart';
import 'core/services/location_manager.dart';
import 'core/services/tracking_service.dart';
import 'core/services/trip_qr_service.dart';
import 'core/services/fcm_service.dart';
import 'core/services/notification_service.dart';
import 'features/auth/auth_wrapper.dart';

// Top-level function to handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FCMService.handleBackgroundMessage(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize local notifications
  await NotificationService().initialize();
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Setup foreground message handler
  FCMService().setupForegroundMessageHandler();
  
  // Setup notification tap handlers for FCM
  _setupFCMNotificationTapHandlers();
  
  runApp(const MyApp());
}

/// Setup FCM notification tap handlers - safely logs without forced navigation
void _setupFCMNotificationTapHandlers() {
  // Handle notification tap when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    try {
      // App opens normally - no forced navigation
    } catch (e) {
    }
  });

  // Handle notification tap when app was terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    try {
      if (message != null) {
        // App opens normally - no forced navigation
      }
    } catch (e) {
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BusService()),
        ChangeNotifierProvider(create: (_) => TripService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LocationManager()),
        ChangeNotifierProvider(create: (_) => TrackingService()),
        ChangeNotifierProvider(create: (_) => TripQRService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) {
          return MaterialApp(
            title: 'PingMyRide',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeService.themeMode,
            home: const AuthWrapper(), // Check auth state on app launch
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

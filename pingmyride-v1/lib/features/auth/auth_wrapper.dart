import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_type.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/fcm_service.dart';
import '../../core/services/notification_listener_service.dart';
import '../navigation/main_navigation.dart';
import 'login_page.dart';

/// AuthWrapper checks Firebase auth state on app launch
/// - If user is logged in, fetches role and navigates to appropriate dashboard
/// - If no user is logged in, shows login screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isChecking = true;
  Widget? _destinationWidget;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.restoreSession();

      // Check if admin is already logged in (hardcoded admin doesn't use Firebase)
      if (mounted) {
        // If admin is already authenticated (from previous session)
        if (authService.currentUserType == UserType.admin && authService.isAuthenticated) {
          setState(() {
            _destinationWidget = const MainNavigation(userType: UserType.admin);
            _isChecking = false;
          });
          return;
        }
      }
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // No user logged in - show login page
        if (!mounted) return;
        setState(() {
          _destinationWidget = const LoginPage();
          _isChecking = false;
        });
        return;
      }

      // User is logged in - fetch their role from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        // User document doesn't exist - force re-login
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          _destinationWidget = const LoginPage();
          _isChecking = false;
        });
        return;
      }

      // Get user type from Firestore
      final userData = doc.data();
      final userTypeString = userData?['userType'] as String?;
      final userType = UserType.values.firstWhere(
        (type) => type.name == userTypeString,
        orElse: () => UserType.student,
      );

      // Set auth service state for driver/student auto-login
      if (mounted) {
        // The AuthService will automatically update via its auth state listener
        // Wait briefly to ensure state is synced
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Initialize FCM for auto-logged in users
        _initializeFCMForAutoLogin(user.uid, userType);
      }

      // Navigate to appropriate dashboard
      if (!mounted) return;
      setState(() {
        _destinationWidget = MainNavigation(userType: userType);
        _isChecking = false;
      });
    } catch (e) {
      // On error, show login page
      if (!mounted) return;
      setState(() {
        _destinationWidget = const LoginPage();
        _isChecking = false;
      });
    }
  }

  // Initialize FCM for users who are auto-logged in
  Future<void> _initializeFCMForAutoLogin(String userId, UserType userType) async {
    try {
      final fcmService = FCMService();
      final permissionGranted = await fcmService.requestPermissionAfterLogin();
      
      if (permissionGranted) {
        await fcmService.storeFCMToken(userId, userType.name);
      }
      
      // Start notification listener for students
      if (userType == UserType.student) {
        final notificationListener = NotificationListenerService();
        await notificationListener.startListening(userId);
      }
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      // Show splash/loading screen while checking auth state
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'PingMyRide',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your reliable ride tracking companion',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 48),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Return the destination widget (either Login or MainNavigation)
    return _destinationWidget ?? const LoginPage();
  }
}

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_type.dart';
import 'fcm_service.dart';
import 'notification_listener_service.dart';

class AuthService extends ChangeNotifier {
  static const String _adminSessionKey = 'admin_session_active';
  static const String _adminEmailKey = 'admin_session_email';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMService _fcmService = FCMService();
  final NotificationListenerService _notificationListenerService = NotificationListenerService();
  
  UserType? _currentUserType;
  String? _currentUserEmail;
  bool _isAuthenticated = false;

  UserType? get currentUserType => _currentUserType;
  String? get currentUserEmail => _currentUserEmail;
  bool get isAuthenticated => _isAuthenticated;
  User? get currentUser => _auth.currentUser;

  AuthService() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        _loadUserData(user);
      } else {
        _currentUserType = null;
        _currentUserEmail = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    });
  }

  Future<void> restoreSession() async {
    // Firebase users are restored automatically by FirebaseAuth.
    if (_auth.currentUser != null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final isAdminSession = prefs.getBool(_adminSessionKey) ?? false;
      final adminEmail = prefs.getString(_adminEmailKey);

      if (isAdminSession && adminEmail != null && adminEmail.isNotEmpty) {
        _currentUserType = UserType.admin;
        _currentUserEmail = adminEmail;
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  Future<void> _loadUserData(User user) async {
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data == null) {
          _currentUserType = null;
          _currentUserEmail = null;
          _isAuthenticated = false;
          notifyListeners();
          return;
        }
        _currentUserType = UserType.values.firstWhere(
          (type) => type.name == data['userType'],
          orElse: () => UserType.student,
        );
        _currentUserEmail = user.email;
        _isAuthenticated = true;
        notifyListeners();
      }
    } catch (e) {
    }
  }

  String _mapAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  Future<Map<String, dynamic>> login(String email, String password, UserType userType) async {
    try {
      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Check if user type matches
        final doc = await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .get();

        if (doc.exists) {
          final userData = doc.data()!;
          final storedUserType = UserType.values.firstWhere(
            (type) => type.name == userData['userType'],
            orElse: () => UserType.student,
          );

          if (storedUserType == userType) {
            // Check email verification for students and drivers
            if ((userType == UserType.student || userType == UserType.driver) && !credential.user!.emailVerified) {
              await _auth.signOut();
              return {
                'success': false,
                'error': 'email_not_verified',
                'message': 'Please verify your email before logging in. Check your inbox for verification link.',
              };
            }

            _currentUserType = userType;
            _currentUserEmail = email;
            _isAuthenticated = true;
            notifyListeners();
            
            // Initialize FCM and store token after successful login
            _initializeFCMForUser(credential.user!.uid, userType);
            
            return {'success': true};
          } else {
            // Wrong user type, sign out
            await _auth.signOut();
            return {
              'success': false,
              'error': 'wrong_user_type',
              'message': 'Invalid credentials for this user type',
            };
          }
        } else {
          // User document doesn't exist, sign out
          await _auth.signOut();
          return {
            'success': false,
            'error': 'user_not_found',
            'message': 'User account not found',
          };
        }
      }
      return {
        'success': false,
        'error': 'unknown',
        'message': 'Login failed',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'error': e.code,
        'message': _mapAuthException(e),
      };
    } on FirebaseException catch (e) {
      return {
        'success': false,
        'error': e.code,
        'message': 'Service temporarily unavailable. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'exception',
        'message': 'Login failed. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> signUp(
    String name, 
    String email, 
    String password, 
    String phone, 
    String idNumber, 
    UserType userType
  ) async {
    try {
      // Block admin signups - admins cannot sign up through the app
      if (userType == UserType.admin) {
        return {
          'success': false,
          'message': 'Admin accounts cannot be created through signup. Please contact system administrator.',
        };
      }
      
      // Create user with Firebase Auth
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Update display name
        await credential.user!.updateDisplayName(name);

        // Save user data to Firestore
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'name': name,
          'email': email,
          'phone': phone,
          'userType': userType.name,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Send email verification for students and drivers
        if (userType == UserType.student || userType == UserType.driver) {
          await credential.user!.sendEmailVerification();
          // Don't set authenticated state until verified
          await _auth.signOut();
          return {
            'success': true,
            'requiresVerification': true,
            'message': 'Verification email sent! Please check your inbox and verify your email before logging in.',
          };
        }

        // For admins only, proceed as normal
        _currentUserType = userType;
        _currentUserEmail = email;
        _isAuthenticated = true;
        notifyListeners();
        return {
          'success': true,
          'requiresVerification': false,
        };
      }
      return {
        'success': false,
        'message': 'Failed to create account',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': _mapAuthException(e),
      };
    } on FirebaseException {
      return {
        'success': false,
        'message': 'Service temporarily unavailable. Please try again.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed. Please try again.',
      };
    }
  }

  Future<void> logout() async {
    try {
      // Remove FCM token before logging out
      if (_auth.currentUser != null && _currentUserType != null) {
        await _fcmService.removeFCMToken(
          _auth.currentUser!.uid,
          _currentUserType!.name,
        );
      }
      
      await _auth.signOut();
      await _notificationListenerService.stopListening();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_adminSessionKey);
      await prefs.remove(_adminEmailKey);
      _currentUserType = null;
      _currentUserEmail = null;
      _isAuthenticated = false;
      notifyListeners();
    } catch (e) {
    }
  }

  bool canAccessRole(UserType requiredRole) {
    return _isAuthenticated && _currentUserType == requiredRole;
  }

  // Set admin login state for hardcoded admin
  void setAdminLogin(String email) {
    _currentUserType = UserType.admin;
    _currentUserEmail = email;
    _isAuthenticated = true;
    _persistAdminSession(email);
    notifyListeners();
  }

  Future<void> _persistAdminSession(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_adminSessionKey, true);
      await prefs.setString(_adminEmailKey, email);
    } catch (e) {
    }
  }

  // Get current user profile data
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    // Handle hardcoded admin login
    if (_currentUserType == UserType.admin && _auth.currentUser == null) {
      // Return hardcoded admin profile data
      return {
        'name': 'TANNEERU CHANDRA SIDHARDHA',
        'email': _currentUserEmail ?? 'chandrasidhardhatanneeru@gmail.com',
        'phone': '7204940447',
        'userType': 'admin',
      };
    }
    
    // For regular Firebase users (students/drivers)
    if (_auth.currentUser != null) {
      try {
        final doc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();
        return doc.data();
      } catch (e) {
      }
    }
    return null;
  }

  // Initialize FCM for logged-in user
  Future<void> _initializeFCMForUser(String userId, UserType userType) async {
    try {
      // Request notification permission
      final permissionGranted = await _fcmService.requestPermissionAfterLogin();
      
      if (permissionGranted) {
        // Store FCM token in Firestore
        await _fcmService.storeFCMToken(userId, userType.name);
      } else {
      }
      
      // Start notification listener for students
      if (userType == UserType.student) {
        await _notificationListenerService.startListening(userId);
      }
    } catch (e) {
    }
  }
}
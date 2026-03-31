import'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/bus.dart';
import '../models/bus_route.dart';
import '../models/booking.dart';
import '../models/bus_timing.dart';import 'notification_service.dart';
class BusService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationService _notificationService = NotificationService();
  
  List<Bus> _buses = [];
  List<BusRoute> _routes = [];
  List<Booking> _userBookings = [];
  List<BusTiming> _busTimings = [];
  bool _isLoading = false;

  List<Bus> get buses => _buses;
  List<BusRoute> get routes => _routes;
  List<Booking> get userBookings => _userBookings;
  List<BusTiming> get busTimings => _busTimings;
  bool get isLoading => _isLoading;

  // Bus operations
  Future<bool> addBus({
    required String busNumber,
    required String driverName,
    required String driverPhone,
    required String driverEmail,
    required int capacity,
    required String routeId,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('buses').add({
        'busNumber': busNumber,
        'driverName': driverName,
        'driverPhone': driverPhone,
        'driverEmail': driverEmail,
        'capacity': capacity,
        'routeId': routeId,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchBuses(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBus(Bus bus) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('buses').doc(bus.id).update({
        ...bus.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await fetchBuses(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBus(String busId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('buses').doc(busId).delete();
      await fetchBuses(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBuses() async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('buses')
          .orderBy('createdAt', descending: true)
          .get();

      _buses = querySnapshot.docs
          .map((doc) => Bus.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _buses = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Route operations
  Future<bool> addRoute({
    required String routeName,
    required String pickupLocation,
    required String dropLocation,
    required List<BusStop> intermediateStops,
    required String estimatedDuration,
    required double distance,
    double baseFare = 50.0,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('routes').add({
        'routeName': routeName,
        'pickupLocation': pickupLocation,
        'dropLocation': dropLocation,
        'intermediateStops': intermediateStops.map((stop) => stop.toMap()).toList(),
        'estimatedDuration': estimatedDuration,
        'distance': distance,
        'baseFare': baseFare,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchRoutes(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateRoute(BusRoute route) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('routes').doc(route.id).update({
        ...route.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await fetchRoutes(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRoute(String routeId) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if any buses are using this route
      final busesUsingRoute = _buses.where((bus) => bus.routeId == routeId).toList();
      if (busesUsingRoute.isNotEmpty) {
        return false;
      }

      await _firestore.collection('routes').doc(routeId).delete();
      await fetchRoutes(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRoutes() async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('routes')
          .orderBy('createdAt', descending: true)
          .get();

      _routes = querySnapshot.docs
          .map((doc) => BusRoute.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _routes = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get route by ID
  BusRoute? getRouteById(String routeId) {
    try {
      return _routes.firstWhere((route) => route.id == routeId);
    } catch (e) {
      return null;
    }
  }

  // Get buses for a specific route
  List<Bus> getBusesForRoute(String routeId) {
    return _buses.where((bus) => bus.routeId == routeId && bus.isActive).toList();
  }

  // Initialize data (call this when service is first used)
  Future<void> initialize() async {
    await Future.wait([
      fetchBuses(),
      fetchRoutes(),
      fetchUserBookings(),
      fetchBusTimings(),
    ]);
  }

  // Booking operations
  Future<bool> bookBus(Bus bus, BusRoute route, {String? selectedTimeSlot, DateTime? selectedBookingDate}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      if (!bus.hasAvailableSeats) {
        return false;
      }

      _isLoading = true;
      notifyListeners();

      // Check if user already has a booking for this bus on the same date and time slot
      if (selectedTimeSlot != null && selectedBookingDate != null) {
        final normalizedDate = DateTime(
          selectedBookingDate.year,
          selectedBookingDate.month,
          selectedBookingDate.day,
        );
        
        final existingBooking = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .where('busId', isEqualTo: bus.id)
            .where('status', isEqualTo: BookingStatus.confirmed.name)
            .where('selectedTimeSlot', isEqualTo: selectedTimeSlot)
            .get();

        // Check if any existing booking matches the same date
        for (var doc in existingBooking.docs) {
          final booking = Booking.fromMap(doc.data(), doc.id);
          if (booking.selectedBookingDate != null) {
            final existingDate = DateTime(
              booking.selectedBookingDate!.year,
              booking.selectedBookingDate!.month,
              booking.selectedBookingDate!.day,
            );
            if (existingDate == normalizedDate) {
              _isLoading = false;
              notifyListeners();
              return false;
            }
          }
        }
      }

      // Get user profile for booking details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Create booking
      final booking = Booking(
        id: '', // Will be set by Firestore
        userId: user.uid,
        userName: userData['name'] ?? 'Unknown',
        userEmail: user.email ?? '',
        busId: bus.id,
        routeId: route.id,
        busNumber: bus.busNumber,
        routeName: route.routeName,
        bookingDate: DateTime.now(),
        pickupLocation: route.pickupLocation,
        dropLocation: route.dropLocation,
        driverName: bus.driverName,
        driverPhone: bus.driverPhone,
        createdAt: DateTime.now(),
        selectedTimeSlot: selectedTimeSlot,
        selectedPickupTime: selectedTimeSlot,
        selectedBookingDate: selectedBookingDate,
      );
      // Use a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Check bus capacity again within transaction
        final busRef = _firestore.collection('buses').doc(bus.id);
        final busSnapshot = await transaction.get(busRef);
        
        if (!busSnapshot.exists) {
          throw Exception('Bus not found');
        }
        
        final currentBus = Bus.fromMap(busSnapshot.data()!, busSnapshot.id);
        if (!currentBus.hasAvailableSeats) {
          throw Exception('No available seats');
        }

        // Create booking document
        final bookingRef = _firestore.collection('bookings').doc();
        transaction.set(bookingRef, booking.toMap());

        // Update bus booked seats count
        transaction.update(busRef, {
          'bookedSeats': currentBus.bookedSeats + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      // Refresh data
      await Future.wait([
        fetchBuses(),
        fetchUserBookings(),
      ]);

      _isLoading = false;
      notifyListeners();
      
      // Send booking confirmation notification
      await _notificationService.showBookingConfirmation(
        routeName: route.routeName,
        time: selectedTimeSlot ?? 'scheduled time',
        busNumber: bus.busNumber,
      );
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Booking with payment details
  Future<bool> bookBusWithPayment(
    Bus bus,
    BusRoute route, {
    required String paymentId,
    required String orderId,
    required String signature,
    String? selectedTimeSlot,
    DateTime? selectedBookingDate,
    String? seatNumber,
    String? gender,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return false;
      }

      if (!bus.hasAvailableSeats) {
        return false;
      }

      _isLoading = true;
      notifyListeners();

      // Check if user already has a booking for this bus on the same date and time slot
      if (selectedTimeSlot != null && selectedBookingDate != null) {
        final normalizedDate = DateTime(
          selectedBookingDate.year,
          selectedBookingDate.month,
          selectedBookingDate.day,
        );
        
        final existingBooking = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .where('busId', isEqualTo: bus.id)
            .where('status', isEqualTo: BookingStatus.confirmed.name)
            .where('selectedTimeSlot', isEqualTo: selectedTimeSlot)
            .get();

        // Check if any existing booking matches the same date
        for (var doc in existingBooking.docs) {
          final booking = Booking.fromMap(doc.data(), doc.id);
          if (booking.selectedBookingDate != null) {
            final existingDate = DateTime(
              booking.selectedBookingDate!.year,
              booking.selectedBookingDate!.month,
              booking.selectedBookingDate!.day,
            );
            if (existingDate == normalizedDate) {
              return false;
            }
          }
        }
      }

      // Get user profile for booking details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      // Generate QR code for the booking
      final qrData = '$paymentId|${user.uid}|${bus.id}|${DateTime.now().millisecondsSinceEpoch}';
      final bytes = utf8.encode(qrData);
      final digest = sha256.convert(bytes);
      final qrCode = digest.toString();

      // Create booking with payment details
      final booking = Booking(
        id: '', // Will be set by Firestore
        userId: user.uid,
        userName: userData['name'] ?? 'Unknown',
        userEmail: user.email ?? '',
        busId: bus.id,
        routeId: route.id,
        busNumber: bus.busNumber,
        routeName: route.routeName,
        bookingDate: DateTime.now(),
        pickupLocation: route.pickupLocation,
        dropLocation: route.dropLocation,
        driverName: bus.driverName,
        driverPhone: bus.driverPhone,
        createdAt: DateTime.now(),
        selectedTimeSlot: selectedTimeSlot,
        selectedPickupTime: selectedTimeSlot,
        selectedBookingDate: selectedBookingDate,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
        amount: 50.0, // Default booking fee from RazorpayConfig
        seatNumber: seatNumber,
        gender: gender,
        qrCode: qrCode,
      );
      // Use a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Check bus capacity again within transaction
        final busRef = _firestore.collection('buses').doc(bus.id);
        final busSnapshot = await transaction.get(busRef);
        
        if (!busSnapshot.exists) {
          throw Exception('Bus not found');
        }
        
        final currentBus = Bus.fromMap(busSnapshot.data()!, busSnapshot.id);
        if (!currentBus.hasAvailableSeats) {
          throw Exception('No available seats');
        }

        // Create booking document
        final bookingRef = _firestore.collection('bookings').doc();
        transaction.set(bookingRef, booking.toMap());

        // Update bus booked seats count
        transaction.update(busRef, {
          'bookedSeats': currentBus.bookedSeats + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      // Refresh data
      await Future.wait([
        fetchBuses(),
        fetchUserBookings(),
      ]);

      _isLoading = false;
      notifyListeners();
      
      // Send booking confirmation notification
      await _notificationService.showBookingConfirmation(
        routeName: route.routeName,
        time: selectedTimeSlot ?? 'scheduled time',
        busNumber: bus.busNumber,
      );
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelBooking(Booking booking) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.uid != booking.userId) {
        return false;
      }

      _isLoading = true;
      notifyListeners();

      // Use a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // IMPORTANT: All reads must happen before all writes in Firestore transactions
        
        // First, read the bus data
        final busRef = _firestore.collection('buses').doc(booking.busId);
        final busSnapshot = await transaction.get(busRef);
        
        // Now perform all write operations
        // Update booking status
        final bookingRef = _firestore.collection('bookings').doc(booking.id);
        transaction.update(bookingRef, {
          'status': BookingStatus.cancelled.name,
          'cancelledAt': FieldValue.serverTimestamp(),
        });

        // Update bus booked seats count
        if (busSnapshot.exists) {
          final currentBus = Bus.fromMap(busSnapshot.data()!, busSnapshot.id);
          transaction.update(busRef, {
            'bookedSeats': (currentBus.bookedSeats - 1).clamp(0, currentBus.capacity),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });

      // Refresh data
      await Future.wait([
        fetchBuses(),
        fetchUserBookings(),
      ]);

      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUserBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _userBookings = [];
        notifyListeners();
        return;
      }
      // Simple query without orderBy to avoid index requirement
      final querySnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();

      _userBookings = querySnapshot.docs
          .map((doc) => Booking.fromMap(doc.data(), doc.id))
          .toList();

      // Sort in memory instead of using Firestore orderBy
      _userBookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    } catch (e) {
      _userBookings = [];
      notifyListeners();
    }
  }

  // Get confirmed bookings for current user
  List<Booking> get confirmedBookings => _userBookings
      .where((booking) => booking.status == BookingStatus.confirmed)
      .toList();

  // Check if user has booking for a specific bus
  bool hasBookingForBus(String busId) {
    return _userBookings.any((booking) =>
        booking.busId == busId && booking.status == BookingStatus.confirmed);
  }

  // Get bus by ID
  Bus? getBusById(String busId) {
    try {
      return _buses.firstWhere((bus) => bus.id == busId);
    } catch (e) {
      return null;
    }
  }

  // Bus Timing operations
  Future<bool> addBusTiming({
    required String busId,
    required String routeId,
    required List<TimingEntry> timings,
    required List<String> daysOfWeek,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('bus_timings').add({
        'busId': busId,
        'routeId': routeId,
        'timings': timings.map((t) => t.toMap()).toList(),
        'daysOfWeek': daysOfWeek,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await fetchBusTimings(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateBusTiming(BusTiming timing) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('bus_timings').doc(timing.id).update({
        ...timing.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await fetchBusTimings(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteBusTiming(String timingId) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _firestore.collection('bus_timings').doc(timingId).delete();
      await fetchBusTimings(); // Refresh the list
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchBusTimings() async {
    try {
      _isLoading = true;
      notifyListeners();

      final querySnapshot = await _firestore
          .collection('bus_timings')
          .orderBy('createdAt', descending: true)
          .get();

      _busTimings = querySnapshot.docs
          .map((doc) => BusTiming.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      _busTimings = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Get timing by bus ID
  BusTiming? getTimingByBusId(String busId) {
    try {
      return _busTimings.firstWhere((timing) => timing.busId == busId && timing.isActive);
    } catch (e) {
      return null;
    }
  }

  // Get all timings for a route
  List<BusTiming> getTimingsByRouteId(String routeId) {
    return _busTimings
        .where((timing) => timing.routeId == routeId && timing.isActive)
        .toList();
  }
}
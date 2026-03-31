import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import '../models/ticket.dart';
import '../models/booking.dart';

class TicketService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Ticket> _userTickets = [];
  bool _isLoading = false;

  List<Ticket> get userTickets => _userTickets;
  bool get isLoading => _isLoading;

  /// Generate a unique QR code for a ticket
  String _generateQRCode(String bookingId, String userId, String busId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$bookingId|$userId|$busId|$timestamp';
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Create a ticket from a booking
  Future<Ticket?> createTicket(Booking booking) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = _auth.currentUser;
      if (user == null) {
        return null;
      }

      // Generate unique QR code
      final qrCode = _generateQRCode(booking.id, user.uid, booking.busId);

      final ticket = Ticket(
        id: '', // Will be set by Firestore
        bookingId: booking.id,
        userId: user.uid,
        busId: booking.busId,
        busNumber: booking.busNumber,
        driverName: booking.driverName,
        driverPhone: booking.driverPhone,
        routeId: booking.routeId,
        routeName: booking.routeName,
        pickupLocation: booking.pickupLocation,
        dropLocation: booking.dropLocation,
        travelDate: booking.selectedBookingDate ?? booking.bookingDate,
        timeSlot: booking.selectedTimeSlot ?? '',
        qrCode: qrCode,
        createdAt: DateTime.now(),
      );

      // Save to Firestore
      final docRef = await _firestore.collection('tickets').add(ticket.toMap());
      await fetchUserTickets();
      return ticket.copyWith(id: docRef.id);
    } catch (e) {
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch user's tickets
  Future<void> fetchUserTickets() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _userTickets = [];
        notifyListeners();
        return;
      }

      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore
          .collection('tickets')
          .where('userId', isEqualTo: user.uid)
          .get();

      _userTickets = snapshot.docs
          .map((doc) => Ticket.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by travel date (most recent first)
      _userTickets.sort((a, b) => b.travelDate.compareTo(a.travelDate));
    } catch (e) {
      _userTickets = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Scan and validate QR code (for drivers)
  Future<Map<String, dynamic>> scanAndValidateQR(String qrCode) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return {
          'success': false,
          'message': 'Driver not authenticated',
        };
      }

      // Find ticket with this QR code
      final snapshot = await _firestore
          .collection('tickets')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return {
          'success': false,
          'message': 'Invalid QR code',
        };
      }

      final ticketDoc = snapshot.docs.first;
      final ticket = Ticket.fromMap(ticketDoc.data(), ticketDoc.id);

      // Check if ticket is already scanned
      if (ticket.status == TicketStatus.active) {
        return {
          'success': false,
          'message': 'Ticket already scanned',
          'ticket': ticket,
        };
      }

      // Check if ticket is for today
      final now = DateTime.now();
      final ticketDate = DateTime(
        ticket.travelDate.year,
        ticket.travelDate.month,
        ticket.travelDate.day,
      );
      final today = DateTime(now.year, now.month, now.day);

      if (ticketDate.isBefore(today)) {
        return {
          'success': false,
          'message': 'Ticket expired',
          'ticket': ticket,
        };
      }

      if (ticketDate.isAfter(today)) {
        return {
          'success': false,
          'message': 'Ticket is for future date',
          'ticket': ticket,
        };
      }

      // Verify driver is assigned to this bus
      final busDoc = await _firestore.collection('buses').doc(ticket.busId).get();
      if (!busDoc.exists) {
        return {
          'success': false,
          'message': 'Bus not found',
        };
      }
      // You can add driver email verification here if needed
      
      // Update ticket status
      await _firestore.collection('tickets').doc(ticketDoc.id).update({
        'status': TicketStatus.active.name,
        'scannedAt': FieldValue.serverTimestamp(),
        'scannedBy': user.uid,
        'rideStartedAt': FieldValue.serverTimestamp(),
      });
      return {
        'success': true,
        'message': 'Ride started successfully',
        'ticket': ticket.copyWith(
          status: TicketStatus.active,
          scannedAt: DateTime.now(),
          scannedBy: user.uid,
          rideStartedAt: DateTime.now(),
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error validating ticket: $e',
      };
    }
  }

  /// Complete a ride
  Future<bool> completeRide(String ticketId) async {
    try {
      await _firestore.collection('tickets').doc(ticketId).update({
        'status': TicketStatus.completed.name,
        'rideCompletedAt': FieldValue.serverTimestamp(),
      });

      await fetchUserTickets();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get ticket by ID
  Future<Ticket?> getTicketById(String ticketId) async {
    try {
      final doc = await _firestore.collection('tickets').doc(ticketId).get();
      if (doc.exists) {
        return Ticket.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get active tickets for a user
  List<Ticket> get activeTickets => _userTickets
      .where((ticket) =>
          ticket.status == TicketStatus.pending ||
          ticket.status == TicketStatus.active)
      .toList();

  /// Get tickets by status
  List<Ticket> getTicketsByStatus(TicketStatus status) =>
      _userTickets.where((ticket) => ticket.status == status).toList();

  /// Stream tickets for a user
  Stream<List<Ticket>> streamUserTickets() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('tickets')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Ticket.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Stream ticket by ID
  Stream<Ticket?> streamTicket(String ticketId) {
    return _firestore
        .collection('tickets')
        .doc(ticketId)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return Ticket.fromMap(snapshot.data()!, snapshot.id);
      }
      return null;
    });
  }
}

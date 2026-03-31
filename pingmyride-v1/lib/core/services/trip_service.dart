import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/trip.dart';
import '../models/bus_route.dart';

/// Trip Service - manages scheduled bus trips
/// Allows admin to create trips (bus + route + date + time)
/// Students can search for trips by stops and date
class TripService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Trip> _trips = [];
  bool _isLoading = false;

  List<Trip> get trips => _trips;
  bool get isLoading => _isLoading;

  /// Initialize trip service and load trips
  Future<void> initialize() async {
    await loadTrips();
  }

  /// Load all trips from Firebase
  Future<void> loadTrips() async {
    try {
      _isLoading = true;
      notifyListeners();

      final snapshot = await _firestore.collection('trips').get();
      _trips = snapshot.docs
          .map((doc) => Trip.fromMap(doc.data(), doc.id))
          .toList();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new trip
  Future<bool> addTrip({
    required String busId,
    required String routeId,
    required String busNumber,
    required String routeName,
    required DateTime tripDate,
    required String departureTime,
    required int totalSeats,
  }) async {
    try {
      final trip = Trip(
        id: '',
        busId: busId,
        routeId: routeId,
        busNumber: busNumber,
        routeName: routeName,
        tripDate: tripDate,
        departureTime: departureTime,
        totalSeats: totalSeats,
        bookedSeats: 0,
        isActive: true,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore.collection('trips').add(trip.toMap());
      final newTrip = trip.copyWith(id: docRef.id);
      _trips.add(newTrip);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Update an existing trip
  Future<bool> updateTrip(Trip trip) async {
    try {
      await _firestore.collection('trips').doc(trip.id).update(trip.toMap());
      final index = _trips.indexWhere((t) => t.id == trip.id);
      if (index != -1) {
        _trips[index] = trip;
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Delete a trip
  Future<bool> deleteTrip(String tripId) async {
    try {
      await _firestore.collection('trips').doc(tripId).delete();
      _trips.removeWhere((t) => t.id == tripId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Search trips by boarding and dropping stops
  /// Returns trips where boarding stop comes before drop stop
  List<Trip> searchTrips({
    required String fromStop,
    required String toStop,
    required DateTime date,
    required List<BusRoute> routes,
  }) {
    // Filter trips by date
    final tripsOnDate = _trips.where((trip) {
      final tripDate = DateTime(
        trip.tripDate.year,
        trip.tripDate.month,
        trip.tripDate.day,
      );
      final searchDate = DateTime(date.year, date.month, date.day);
      return tripDate.isAtSameMomentAs(searchDate) &&
          trip.isActive &&
          trip.hasAvailableSeats;
    }).toList();

    // Filter trips by route stops
    final matchingTrips = <Trip>[];
    for (final trip in tripsOnDate) {
      final route = routes.firstWhere(
        (r) => r.id == trip.routeId,
        orElse: () => BusRoute(
          id: '',
          routeName: '',
          pickupLocation: '',
          dropLocation: '',
          estimatedDuration: '',
          distance: 0,
          createdAt: DateTime.now(),
        ),
      );

      if (route.id.isEmpty) continue;

      // Check if route has the required stops in correct order
      if (_routeHasStops(route, fromStop, toStop)) {
        matchingTrips.add(trip);
      }
    }

    return matchingTrips;
  }

  /// Check if a route has the required stops in correct order
  bool _routeHasStops(BusRoute route, String fromStop, String toStop) {
    // Build complete stop list: start + intermediate + end
    final allStops = <String>[];
    allStops.add(route.pickupLocation.toLowerCase());
    
    for (final stop in route.intermediateStops) {
      allStops.add(stop.name.toLowerCase());
    }
    
    allStops.add(route.dropLocation.toLowerCase());

    // Find indices of from and to stops
    final fromIndex = allStops.indexWhere(
        (stop) => stop.contains(fromStop.toLowerCase()));
    final toIndex = allStops.indexWhere(
        (stop) => stop.contains(toStop.toLowerCase()));

    // Both stops must exist and from must come before to
    return fromIndex != -1 && toIndex != -1 && fromIndex < toIndex;
  }

  /// Get trip by ID
  Trip? getTripById(String tripId) {
    try {
      return _trips.firstWhere((trip) => trip.id == tripId);
    } catch (e) {
      return null;
    }
  }

  /// Get trips for a specific bus
  List<Trip> getTripsForBus(String busId) {
    return _trips.where((trip) => trip.busId == busId).toList();
  }

  /// Get trips for a specific route
  List<Trip> getTripsForRoute(String routeId) {
    return _trips.where((trip) => trip.routeId == routeId).toList();
  }

  /// Get upcoming trips (future trips only)
  List<Trip> getUpcomingTrips() {
    final now = DateTime.now();
    return _trips.where((trip) {
      return trip.tripDate.isAfter(now) && trip.isActive;
    }).toList()
      ..sort((a, b) => a.tripDate.compareTo(b.tripDate));
  }

  /// Update booked seats count (called after booking)
  Future<bool> updateBookedSeats(String tripId, int bookedSeats) async {
    try {
      await _firestore.collection('trips').doc(tripId).update({
        'bookedSeats': bookedSeats,
        'updatedAt': DateTime.now(),
      });

      final index = _trips.indexWhere((t) => t.id == tripId);
      if (index != -1) {
        _trips[index] = _trips[index].copyWith(
          bookedSeats: bookedSeats,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}

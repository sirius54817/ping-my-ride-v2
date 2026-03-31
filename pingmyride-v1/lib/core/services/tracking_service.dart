import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import '../models/bus_route.dart';

/// Central tracking service for real-time bus location updates
class TrackingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PolylinePoints _polylinePoints = PolylinePoints();

  // Active tracking streams
  final Map<String, StreamSubscription<DocumentSnapshot>> _busStreams = {};
  final Map<String, LatLng> _busLocations = {};
  final Map<String, Map<String, dynamic>> _busData = {};
  
  // Polylines for routes
  final Map<String, List<LatLng>> _routePolylines = {};
  
  // API Key for Google Maps Directions API
  static const String _googleMapsApiKey = 'AIzaSyC2tlZohyy8aBukmpFHr7vXSGXoGvIc6XU';

  /// Get current location of a bus
  LatLng? getBusLocation(String busId) {
    return _busLocations[busId];
  }

  /// Get bus data (speed, heading, etc.)
  Map<String, dynamic>? getBusData(String busId) {
    return _busData[busId];
  }

  /// Get route polyline
  List<LatLng>? getRoutePolyline(String routeId) {
    return _routePolylines[routeId];
  }

  /// Start tracking a specific bus
  Future<void> startTrackingBus(String busId) async {
    if (_busStreams.containsKey(busId)) {
      return;
    }
    _busStreams[busId] = _firestore
        .collection('buses')
        .doc(busId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && data['currentLocation'] != null) {
          final GeoPoint geoPoint = data['currentLocation'];
          _busLocations[busId] = LatLng(geoPoint.latitude, geoPoint.longitude);
          _busData[busId] = {
            'speed': data['speed'] ?? 0.0,
            'heading': data['heading'] ?? 0.0,
            'lastUpdate': data['lastLocationUpdate'],
            'isActive': data['isActive'] ?? false,
          };
          notifyListeners();
        }
      }
    });
  }

  /// Stop tracking a specific bus
  void stopTrackingBus(String busId) {
    _busStreams[busId]?.cancel();
    _busStreams.remove(busId);
    _busLocations.remove(busId);
    _busData.remove(busId);
    notifyListeners();
  }

  /// Stop all tracking
  void stopAllTracking() {
    for (var subscription in _busStreams.values) {
      subscription.cancel();
    }
    _busStreams.clear();
    _busLocations.clear();
    _busData.clear();
    notifyListeners();
  }

  /// Fetch and create polyline for a route
  Future<List<LatLng>> fetchRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    List<LatLng>? waypoints,
  }) async {
    try {
      final result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(origin.latitude, origin.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
          wayPoints: waypoints?.map((point) => PolylineWayPoint(
            location: '${point.latitude},${point.longitude}',
          )).toList() ?? [],
        ),
      );

      if (result.points.isNotEmpty) {
        final polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        return polylineCoordinates;
      } else if (result.errorMessage != null) {
      }

      // Fallback: return straight line
      return [origin, destination];
    } catch (e) {
      return [origin, destination];
    }
  }

  /// Cache route polyline
  void cacheRoutePolyline(String routeId, List<LatLng> polyline) {
    _routePolylines[routeId] = polyline;
    notifyListeners();
  }

  /// Fetch route polyline from BusRoute model
  Future<List<LatLng>> fetchRoutePolylineFromRoute(BusRoute route) async {
    // Check cache first
    if (_routePolylines.containsKey(route.id)) {
      return _routePolylines[route.id]!;
    }

    // Create origin and destination
    final origin = LatLng(
      route.pickupLocation.hashCode.toDouble() / 1000000, // Placeholder
      route.pickupLocation.hashCode.toDouble() / 1000000,
    );
    final destination = LatLng(
      route.dropLocation.hashCode.toDouble() / 1000000, // Placeholder
      route.dropLocation.hashCode.toDouble() / 1000000,
    );

    // Add waypoints from intermediate stops
    final waypoints = route.intermediateStops
        .map((stop) => LatLng(
              stop.name.hashCode.toDouble() / 1000000, // Placeholder
              stop.name.hashCode.toDouble() / 1000000,
            ))
        .toList();

    final polyline = await fetchRoutePolyline(
      origin: origin,
      destination: destination,
      waypoints: waypoints,
    );

    cacheRoutePolyline(route.id, polyline);
    return polyline;
  }

  /// Get real-time location history for a bus
  Stream<List<Map<String, dynamic>>> streamBusLocationHistory(
    String busId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('location_history')
        .where('busId', isEqualTo: busId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  /// Calculate ETA based on current bus location and destination
  Future<Map<String, dynamic>> calculateETA({
    required LatLng currentLocation,
    required LatLng destination,
    double currentSpeed = 0, // in m/s
  }) async {
    try {
      final result = await _polylinePoints.getRouteBetweenCoordinates(
        googleApiKey: _googleMapsApiKey,
        request: PolylineRequest(
          origin: PointLatLng(currentLocation.latitude, currentLocation.longitude),
          destination: PointLatLng(destination.latitude, destination.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        // Calculate total distance
        double totalDistance = 0;
        for (int i = 0; i < result.points.length - 1; i++) {
          totalDistance += _calculateDistance(
            result.points[i].latitude,
            result.points[i].longitude,
            result.points[i + 1].latitude,
            result.points[i + 1].longitude,
          );
        }

        // Calculate ETA (using average speed if current speed is too low)
        final avgSpeed = currentSpeed < 5 ? 30 / 3.6 : currentSpeed; // 30 km/h default
        final eta = Duration(seconds: (totalDistance / avgSpeed).round());

        return {
          'distance': totalDistance,
          'eta': eta,
          'etaMinutes': eta.inMinutes,
          'etaFormatted': _formatDuration(eta),
        };
      }

      return {
        'distance': 0.0,
        'eta': Duration.zero,
        'etaMinutes': 0,
        'etaFormatted': 'N/A',
      };
    } catch (e) {
      return {
        'distance': 0.0,
        'eta': Duration.zero,
        'etaMinutes': 0,
        'etaFormatted': 'N/A',
      };
    }
  }

  /// Calculate distance between two points (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * 3.14159 / 180;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  void dispose() {
    stopAllTracking();
    super.dispose();
  }
}

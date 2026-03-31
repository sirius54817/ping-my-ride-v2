import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/services/tracking_service.dart';
import '../../core/services/bus_service.dart';
import '../../core/theme/app_theme.dart';

class BusTrackingMapPage extends StatefulWidget {
  final String busId;
  final String? routeId;

  const BusTrackingMapPage({
    super.key,
    required this.busId,
    this.routeId,
  });

  @override
  State<BusTrackingMapPage> createState() => _BusTrackingMapPageState();
}

class _BusTrackingMapPageState extends State<BusTrackingMapPage> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Timer? _updateTimer;
  LatLng? _busLocation;
  Map<String, dynamic>? _busData;

  @override
  void initState() {
    super.initState();
    _initializeTracking();
  }

  Future<void> _initializeTracking() async {
    final trackingService = Provider.of<TrackingService>(context, listen: false);
    
    // Start tracking the bus
    await trackingService.startTrackingBus(widget.busId);
    if (!mounted) return;

    // Load route polyline if routeId is provided
    if (widget.routeId != null) {
      final busService = Provider.of<BusService>(context, listen: false);
      final route = busService.getRouteById(widget.routeId!);
      
      if (route != null) {
        final polyline = await trackingService.fetchRoutePolylineFromRoute(route);
        if (mounted) {
          setState(() {
            _polylines.add(Polyline(
              polylineId: PolylineId('route_${widget.routeId}'),
              points: polyline,
              color: AppTheme.primaryColor,
              width: 5,
              patterns: [
                PatternItem.dash(20),
                PatternItem.gap(10),
              ],
            ));
          });
        }
      }
    }

    // Set up periodic updates
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateBusMarker();
    });

    // Initial update
    _updateBusMarker();
  }

  void _updateBusMarker() {
    if (!mounted) return;
    final trackingService = Provider.of<TrackingService>(context, listen: false);
    final location = trackingService.getBusLocation(widget.busId);
    final data = trackingService.getBusData(widget.busId);

    if (location != null) {
      setState(() {
        _busLocation = location;
        _busData = data;
        
        _markers.clear();
        _markers.add(Marker(
          markerId: MarkerId('bus_${widget.busId}'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: 'Bus Location',
            snippet: data != null
                ? 'Speed: ${(data['speed'] * 3.6).toStringAsFixed(1)} km/h'
                : null,
          ),
          rotation: data?['heading'] ?? 0.0,
        ));
      });

      // Move camera to bus location
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(location, 15),
      );
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _mapController?.dispose();
    final trackingService = Provider.of<TrackingService>(context, listen: false);
    trackingService.stopTrackingBus(widget.busId);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Bus Tracking'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              if (_busLocation != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_busLocation!, 15),
                );
              }
            },
            icon: const Icon(Icons.my_location),
            tooltip: 'Center on bus',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _busLocation ?? const LatLng(0, 0),
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          // Bus info card at bottom
          if (_busData != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBusInfoCard(),
            ),

          // Loading indicator
          if (_busLocation == null)
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Locating bus...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBusInfoCard() {
    final speed = (_busData!['speed'] * 3.6).toStringAsFixed(1);
    final heading = _busData!['heading'].toStringAsFixed(0);
    final isActive = _busData!['isActive'] ?? false;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_bus,
                    color: isActive ? Colors.green : Colors.red,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bus Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive ? 'Active & Moving' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(
                  icon: Icons.speed,
                  label: 'Speed',
                  value: '$speed km/h',
                ),
                _buildInfoItem(
                  icon: Icons.explore,
                  label: 'Heading',
                  value: '$heading°',
                ),
                _buildInfoItem(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: 'Live',
                  valueColor: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

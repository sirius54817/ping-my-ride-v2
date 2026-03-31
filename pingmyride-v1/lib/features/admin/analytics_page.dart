import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/bus_service.dart';
import '../../core/models/booking.dart';
import 'bookings_management_page.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalBookings = 0;
  int _confirmedBookings = 0;
  int _cancelledBookings = 0;
  double _totalRevenue = 0.0;
  final Map<String, int> _busBookingStats = {};
  final Map<String, int> _routeBookingStats = {};

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      // Fetch total users
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;

      // Fetch all bookings
      final bookingsSnapshot = await _firestore.collection('bookings').get();
      _totalBookings = bookingsSnapshot.docs.length;

      _confirmedBookings = 0;
      _cancelledBookings = 0;
      _totalRevenue = 0.0;
      _busBookingStats.clear();
      _routeBookingStats.clear();

      for (var doc in bookingsSnapshot.docs) {
        final booking = Booking.fromMap(doc.data(), doc.id);
        
        if (booking.status == BookingStatus.confirmed) {
          _confirmedBookings++;
          if (booking.amount != null) {
            _totalRevenue += booking.amount!;
          }
        } else if (booking.status == BookingStatus.cancelled) {
          _cancelledBookings++;
        }

        // Bus booking stats
        _busBookingStats[booking.busNumber] = 
            (_busBookingStats[booking.busNumber] ?? 0) + 1;

        // Route booking stats
        _routeBookingStats[booking.routeName] = 
            (_routeBookingStats[booking.routeName] ?? 0) + 1;
      }
    } catch (e) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh analytics',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Cards
                    _buildSectionHeader('System Overview'),
                    const SizedBox(height: 16),
                    _buildOverviewCards(),
                    
                    const SizedBox(height: 32),
                    
                    // Revenue Card
                    _buildSectionHeader('Financial Overview'),
                    const SizedBox(height: 16),
                    _buildRevenueCard(),
                    
                    const SizedBox(height: 32),
                    
                    // Bus Performance
                    _buildSectionHeader('Bus Performance'),
                    const SizedBox(height: 16),
                    _buildBusPerformance(),
                    
                    const SizedBox(height: 32),
                    
                    // Route Performance
                    _buildSectionHeader('Route Performance'),
                    const SizedBox(height: 16),
                    _buildRoutePerformance(),
                    
                    const SizedBox(height: 32),
                    
                    // System Statistics
                    _buildSectionHeader('System Statistics'),
                    const SizedBox(height: 16),
                    _buildSystemStats(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildOverviewCards() {
    final busService = Provider.of<BusService>(context);
    
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Users',
          _totalUsers.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildStatCard(
          'Total Buses',
          busService.buses.length.toString(),
          Icons.directions_bus,
          Colors.green,
        ),
        _buildStatCard(
          'Total Routes',
          busService.routes.length.toString(),
          Icons.route,
          Colors.orange,
        ),
        _buildStatCard(
          'Total Bookings',
          _totalBookings.toString(),
          Icons.confirmation_number,
          Colors.purple,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BookingsManagementPage(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    final card = Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }
    return card;
  }

  Widget _buildRevenueCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Revenue',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '₹${_totalRevenue.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    size: 40,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRevenueMetric(
                  'Confirmed',
                  _confirmedBookings.toString(),
                  Colors.green,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildRevenueMetric(
                  'Cancelled',
                  _cancelledBookings.toString(),
                  Colors.red,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildRevenueMetric(
                  'Avg/Booking',
                  _confirmedBookings > 0 
                      ? '₹${(_totalRevenue / _confirmedBookings).toStringAsFixed(0)}'
                      : '₹0',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildBusPerformance() {
    if (_busBookingStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.directions_bus_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No booking data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort by bookings count
    final sortedBuses = _busBookingStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Performing Buses',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  label: Text('${sortedBuses.length} Buses'),
                  backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedBuses.take(5).map((entry) {
              final percentage = (_totalBookings > 0)
                  ? (entry.value / _totalBookings * 100)
                  : 0.0;
              return _buildPerformanceItem(
                entry.key,
                entry.value,
                percentage,
                Colors.blue,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutePerformance() {
    if (_routeBookingStats.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.route_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No route data available',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Sort by bookings count
    final sortedRoutes = _routeBookingStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Popular Routes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Chip(
                  label: Text('${sortedRoutes.length} Routes'),
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...sortedRoutes.take(5).map((entry) {
              final percentage = (_totalBookings > 0)
                  ? (entry.value / _totalBookings * 100)
                  : 0.0;
              return _buildPerformanceItem(
                entry.key,
                entry.value,
                percentage,
                Colors.green,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceItem(
    String name,
    int count,
    double percentage,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count bookings (${percentage.toStringAsFixed(1)}%)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStats() {
    final busService = Provider.of<BusService>(context);
    final activeBuses = busService.buses.where((b) => b.isActive).length;
    final inactiveBuses = busService.buses.length - activeBuses;
    final activeRoutes = busService.routes.where((r) => r.isActive).length;
    final totalCapacity = busService.buses.fold<int>(
      0,
      (total, bus) => total + bus.capacity,
    );
    final bookedSeats = busService.buses.fold<int>(
      0,
      (total, bus) => total + bus.bookedSeats,
    );
    final availableSeats = totalCapacity - bookedSeats;
    final occupancyRate = totalCapacity > 0 
        ? (bookedSeats / totalCapacity * 100) 
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Health',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            _buildStatRow('Active Buses', '$activeBuses / ${busService.buses.length}', Icons.check_circle, Colors.green),
            const Divider(height: 24),
            _buildStatRow('Inactive Buses', inactiveBuses.toString(), Icons.cancel, Colors.red),
            const Divider(height: 24),
            _buildStatRow('Active Routes', '$activeRoutes / ${busService.routes.length}', Icons.route, Colors.blue),
            const Divider(height: 24),
            _buildStatRow('Total Capacity', '$totalCapacity seats', Icons.event_seat, Colors.purple),
            const Divider(height: 24),
            _buildStatRow('Booked Seats', '$bookedSeats seats', Icons.airline_seat_recline_normal, Colors.orange),
            const Divider(height: 24),
            _buildStatRow('Available Seats', '$availableSeats seats', Icons.event_available, Colors.teal),
            const Divider(height: 24),
            _buildStatRow('Occupancy Rate', '${occupancyRate.toStringAsFixed(1)}%', Icons.trending_up, 
                occupancyRate > 70 ? Colors.green : occupancyRate > 40 ? Colors.orange : Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }
}

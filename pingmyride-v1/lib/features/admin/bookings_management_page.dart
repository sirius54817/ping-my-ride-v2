import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/bus_service.dart';
import '../../core/models/booking.dart';

enum BookingSortOption {
  dateNewest,
  dateOldest,
  amountHighest,
  amountLowest,
  busNumber,
  routeName,
}

enum BookingFilterOption {
  all,
  confirmed,
  cancelled,
  completed,
}

class BookingsManagementPage extends StatefulWidget {
  const BookingsManagementPage({super.key});

  @override
  State<BookingsManagementPage> createState() => _BookingsManagementPageState();
}

class _BookingsManagementPageState extends State<BookingsManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Booking> _allBookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;
  
  BookingSortOption _currentSort = BookingSortOption.dateNewest;
  BookingFilterOption _currentFilter = BookingFilterOption.all;
  String _searchQuery = '';
  
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      final querySnapshot = await _firestore
          .collection('bookings')
          .orderBy('createdAt', descending: true)
          .get();

      _allBookings = querySnapshot.docs
          .map((doc) => Booking.fromMap(doc.data(), doc.id))
          .toList();

      _applyFiltersAndSort();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    // Apply filter
    List<Booking> filtered = _allBookings;

    switch (_currentFilter) {
      case BookingFilterOption.confirmed:
        filtered = filtered.where((b) => b.status == BookingStatus.confirmed).toList();
        break;
      case BookingFilterOption.cancelled:
        filtered = filtered.where((b) => b.status == BookingStatus.cancelled).toList();
        break;
      case BookingFilterOption.completed:
        filtered = filtered.where((b) => b.status == BookingStatus.completed).toList();
        break;
      case BookingFilterOption.all:
        break;
    }

    // Apply search
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((booking) {
        return booking.busNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.routeName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.pickupLocation.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.dropLocation.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Apply sort
    switch (_currentSort) {
      case BookingSortOption.dateNewest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case BookingSortOption.dateOldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case BookingSortOption.amountHighest:
        filtered.sort((a, b) => (b.amount ?? 0).compareTo(a.amount ?? 0));
        break;
      case BookingSortOption.amountLowest:
        filtered.sort((a, b) => (a.amount ?? 0).compareTo(b.amount ?? 0));
        break;
      case BookingSortOption.busNumber:
        filtered.sort((a, b) => a.busNumber.compareTo(b.busNumber));
        break;
      case BookingSortOption.routeName:
        filtered.sort((a, b) => a.routeName.compareTo(b.routeName));
        break;
    }

    setState(() {
      _filteredBookings = filtered;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadBookings,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search, Filter, and Sort Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by bus, route, user, or location...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _applyFiltersAndSort();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                    _applyFiltersAndSort();
                  },
                ),
                const SizedBox(height: 12),
                // Filter and Sort Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showFilterDialog,
                        icon: Icon(_getFilterIcon()),
                        label: Text(_getFilterLabel()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showSortDialog,
                        icon: const Icon(Icons.sort),
                        label: Text(_getSortLabel()),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Stats Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatChip(
                  'Total',
                  _filteredBookings.length.toString(),
                  Colors.blue,
                ),
                _buildStatChip(
                  'Confirmed',
                  _filteredBookings.where((b) => b.status == BookingStatus.confirmed).length.toString(),
                  Colors.green,
                ),
                _buildStatChip(
                  'Cancelled',
                  _filteredBookings.where((b) => b.status == BookingStatus.cancelled).length.toString(),
                  Colors.red,
                ),
              ],
            ),
          ),

          // Bookings List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty || _currentFilter != BookingFilterOption.all
                                  ? 'No bookings found'
                                  : 'No bookings yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (_searchQuery.isNotEmpty || _currentFilter != BookingFilterOption.all) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _currentFilter = BookingFilterOption.all;
                                  });
                                  _applyFiltersAndSort();
                                },
                                child: const Text('Clear filters'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadBookings,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _filteredBookings.length,
                          itemBuilder: (context, index) {
                            final booking = _filteredBookings[index];
                            return _buildBookingCard(booking);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final busService = Provider.of<BusService>(context, listen: false);
    final bus = busService.getBusById(booking.busId);
    final route = bus != null ? busService.getRouteById(bus.routeId) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showBookingDetails(booking, bus, route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      booking.busNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(booking.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(booking.status),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      booking.status.label,
                      style: TextStyle(
                        color: _getStatusColor(booking.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(Icons.person, 'Passenger', booking.userName),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.route, 'Route', booking.routeName),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.location_on, 'Pickup', booking.pickupLocation),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.location_off, 'Drop', booking.dropLocation),
              const SizedBox(height: 6),
              _buildInfoRow(Icons.calendar_today, 'Booked On', _formatDate(booking.createdAt)),
              if (booking.amount != null) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  Icons.payment,
                  'Amount',
                  '₹${booking.amount!.toStringAsFixed(2)}',
                  valueColor: Colors.green,
                ),
              ],
              if (booking.status == BookingStatus.cancelled && booking.cancelledAt != null) ...[
                const SizedBox(height: 6),
                _buildInfoRow(
                  Icons.cancel,
                  'Cancelled On',
                  _formatDate(booking.cancelledAt!),
                  valueColor: Colors.red,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  IconData _getFilterIcon() {
    switch (_currentFilter) {
      case BookingFilterOption.all:
        return Icons.filter_list;
      case BookingFilterOption.confirmed:
        return Icons.check_circle;
      case BookingFilterOption.cancelled:
        return Icons.cancel;
      case BookingFilterOption.completed:
        return Icons.check_circle_outline;
    }
  }

  String _getFilterLabel() {
    switch (_currentFilter) {
      case BookingFilterOption.all:
        return 'All Bookings';
      case BookingFilterOption.confirmed:
        return 'Confirmed';
      case BookingFilterOption.cancelled:
        return 'Cancelled';
      case BookingFilterOption.completed:
        return 'Completed';
    }
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case BookingSortOption.dateNewest:
        return 'Newest First';
      case BookingSortOption.dateOldest:
        return 'Oldest First';
      case BookingSortOption.amountHighest:
        return 'Amount: High-Low';
      case BookingSortOption.amountLowest:
        return 'Amount: Low-High';
      case BookingSortOption.busNumber:
        return 'Bus Number';
      case BookingSortOption.routeName:
        return 'Route Name';
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Bookings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BookingFilterOption.values.map((option) {
            return RadioListTile<BookingFilterOption>(
              title: Text(_getFilterOptionLabel(option)),
              value: option,
              groupValue: _currentFilter,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _currentFilter = value!;
                });
                _applyFiltersAndSort();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Bookings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: BookingSortOption.values.map((option) {
            return RadioListTile<BookingSortOption>(
              title: Text(_getSortOptionLabel(option)),
              value: option,
              groupValue: _currentSort,
              onChanged: (value) {
                Navigator.pop(context);
                setState(() {
                  _currentSort = value!;
                });
                _applyFiltersAndSort();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _getFilterOptionLabel(BookingFilterOption option) {
    switch (option) {
      case BookingFilterOption.all:
        return 'All Bookings';
      case BookingFilterOption.confirmed:
        return 'Confirmed Only';
      case BookingFilterOption.cancelled:
        return 'Cancelled Only';
      case BookingFilterOption.completed:
        return 'Completed Only';
    }
  }

  String _getSortOptionLabel(BookingSortOption option) {
    switch (option) {
      case BookingSortOption.dateNewest:
        return 'Date: Newest First';
      case BookingSortOption.dateOldest:
        return 'Date: Oldest First';
      case BookingSortOption.amountHighest:
        return 'Amount: Highest First';
      case BookingSortOption.amountLowest:
        return 'Amount: Lowest First';
      case BookingSortOption.busNumber:
        return 'Bus Number (A-Z)';
      case BookingSortOption.routeName:
        return 'Route Name (A-Z)';
    }
  }

  void _showBookingDetails(Booking booking, bus, route) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.confirmation_number, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Booking Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ID: ${booking.id.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailSection('Passenger Information', [
                        _buildDetailRow('Name', booking.userName),
                        _buildDetailRow('User ID', booking.userId),
                      ]),
                      const Divider(height: 32),
                      _buildDetailSection('Bus & Route Information', [
                        _buildDetailRow('Bus Number', booking.busNumber),
                        _buildDetailRow('Route', booking.routeName),
                        _buildDetailRow('Pickup Location', booking.pickupLocation),
                        _buildDetailRow('Drop Location', booking.dropLocation),
                        if (route != null) _buildDetailRow('Duration', route.estimatedDuration),
                        if (route != null) _buildDetailRow('Distance', '${route.distance} km'),
                      ]),
                      const Divider(height: 32),
                      _buildDetailSection('Booking Information', [
                        _buildDetailRow('Status', booking.status.label, 
                            valueColor: _getStatusColor(booking.status)),
                        _buildDetailRow('Booked On', _formatDateTime(booking.createdAt)),
                        if (booking.amount != null)
                          _buildDetailRow('Amount', '₹${booking.amount!.toStringAsFixed(2)}',
                              valueColor: Colors.green),
                        if (booking.status == BookingStatus.cancelled && booking.cancelledAt != null)
                          _buildDetailRow('Cancelled On', _formatDateTime(booking.cancelledAt!),
                              valueColor: Colors.red),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.completed:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

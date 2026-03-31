import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/booking.dart';
import '../../core/models/bus.dart';
import '../../core/models/bus_route.dart';
import '../../core/services/bus_service.dart';
import '../../core/theme/app_theme.dart';
import '../tracking/location_tracking_page.dart';
import '../tracking/bus_tracking_map_page.dart';
import '../student/student_scan_qr_page.dart';

/// Filter options for bookings
enum BookingFilter { all, confirmed, cancelled, completed }

/// Sort options for bookings
enum BookingSort { upcoming, recent, oldest }

class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  BookingFilter _currentFilter = BookingFilter.all;
  BookingSort _currentSort = BookingSort.upcoming;
  final Set<String> _expandedBookings = {};

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<BusService>(context, listen: false).fetchUserBookings();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<BusService>(
        builder: (context, busService, child) {
          if (busService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filteredBookings = _getFilteredAndSortedBookings(busService.userBookings);

          if (filteredBookings.isEmpty) {
            return _buildEmptyState();
          }

          return Column(
            children: [
              if (_hasActiveFiltersOrSort) _buildFilterInfo(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => busService.fetchUserBookings(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredBookings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final booking = filteredBookings[index];
                      final bus = busService.getBusById(booking.busId);
                      final route = busService.getRouteById(booking.routeId);
                      return _BookingCard(
                        booking: booking,
                        bus: bus,
                        route: route,
                        isExpanded: _expandedBookings.contains(booking.id),
                        onToggleExpand: () => _toggleExpansion(booking.id),
                        onCancel: () => _cancelBooking(context, booking, busService),
                        onTrack: () => _trackBus(context, booking),
                        onShowTicket: () => _showTicket(context, booking),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('My Bookings'),
      elevation: 0,
      actions: [
        _buildSortButton(),
        _buildFilterButton(),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildSortButton() {
    return PopupMenuButton<BookingSort>(
      icon: const Icon(Icons.sort),
      tooltip: 'Sort by',
      onSelected: (sort) => setState(() => _currentSort = sort),
      itemBuilder: (context) => [
        _buildSortMenuItem(BookingSort.upcoming, Icons.schedule, 'Upcoming First'),
        _buildSortMenuItem(BookingSort.recent, Icons.access_time, 'Most Recent'),
        _buildSortMenuItem(BookingSort.oldest, Icons.history, 'Oldest First'),
      ],
    );
  }

  PopupMenuItem<BookingSort> _buildSortMenuItem(
    BookingSort value,
    IconData icon,
    String label,
  ) {
    final isSelected = _currentSort == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? AppTheme.primaryColor : null),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : null,
              color: isSelected ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<BookingFilter>(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Filter',
      onSelected: (filter) => setState(() => _currentFilter = filter),
      itemBuilder: (context) => [
        _buildFilterMenuItem(BookingFilter.all, Icons.all_inclusive, 'All'),
        _buildFilterMenuItem(BookingFilter.confirmed, Icons.check_circle, 'Confirmed', Colors.green),
        _buildFilterMenuItem(BookingFilter.cancelled, Icons.cancel, 'Cancelled', Colors.red),
        _buildFilterMenuItem(BookingFilter.completed, Icons.check_circle_outline, 'Completed', Colors.blue),
      ],
    );
  }

  PopupMenuItem<BookingFilter> _buildFilterMenuItem(
    BookingFilter value,
    IconData icon,
    String label, [
    Color? iconColor,
  ]) {
    final isSelected = _currentFilter == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : iconColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : null,
              color: isSelected ? AppTheme.primaryColor : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      onPressed: () async {
        await Provider.of<BusService>(context, listen: false).fetchUserBookings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bookings refreshed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      icon: const Icon(Icons.refresh),
      tooltip: 'Refresh bookings',
    );
  }

  Widget _buildFilterInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing ${_currentFilter.name} bookings sorted by ${_getSortLabel()}',
              style: TextStyle(fontSize: 12, color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _currentFilter = BookingFilter.all;
              _currentSort = BookingSort.upcoming;
            }),
            child: const Text('Clear', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            _currentFilter == BookingFilter.all
                ? 'No bookings yet'
                : 'No ${_currentFilter.name} bookings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _currentFilter == BookingFilter.all
                ? 'Your bus bookings will appear here'
                : 'Try changing the filter',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveFiltersOrSort =>
      _currentFilter != BookingFilter.all || _currentSort != BookingSort.upcoming;

  List<Booking> _getFilteredAndSortedBookings(List<Booking> bookings) {
    var filtered = bookings;

    // Apply filter
    switch (_currentFilter) {
      case BookingFilter.confirmed:
        filtered = bookings.where((b) => b.status == BookingStatus.confirmed).toList();
        break;
      case BookingFilter.cancelled:
        filtered = bookings.where((b) => b.status == BookingStatus.cancelled).toList();
        break;
      case BookingFilter.completed:
        filtered = bookings.where((b) => b.status == BookingStatus.completed).toList();
        break;
      case BookingFilter.all:
        break;
    }

    // Apply sort
    switch (_currentSort) {
      case BookingSort.upcoming:
        filtered.sort(_compareUpcoming);
        break;
      case BookingSort.recent:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case BookingSort.oldest:
        filtered.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
    }

    return filtered;
  }

  int _compareUpcoming(Booking a, Booking b) {
    final aTime = _BookingUtils.getBookingDateTime(a);
    final bTime = _BookingUtils.getBookingDateTime(b);

    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;

    final now = DateTime.now();
    final aDiff = aTime.difference(now);
    final bDiff = bTime.difference(now);

    // Both in past - sort by most recent
    if (aDiff.isNegative && bDiff.isNegative) {
      return bTime.compareTo(aTime);
    }

    // One in past, one in future - future comes first
    if (aDiff.isNegative) return 1;
    if (bDiff.isNegative) return -1;

    // Both in future - sort by closest first
    return aTime.compareTo(bTime);
  }

  String _getSortLabel() {
    switch (_currentSort) {
      case BookingSort.upcoming:
        return 'upcoming first';
      case BookingSort.recent:
        return 'most recent';
      case BookingSort.oldest:
        return 'oldest first';
    }
  }

  void _toggleExpansion(String bookingId) {
    setState(() {
      if (_expandedBookings.contains(bookingId)) {
        _expandedBookings.remove(bookingId);
      } else {
        _expandedBookings.add(bookingId);
      }
    });
  }

  Future<void> _cancelBooking(
    BuildContext context,
    Booking booking,
    BusService busService,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel your booking for bus ${booking.busNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await busService.cancelBooking(booking);

      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Booking cancelled successfully' : 'Failed to cancel booking',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  void _trackBus(BuildContext context, Booking booking) {
    // Show options for different tracking views
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map View'),
              subtitle: const Text('Track bus on live map with route'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusTrackingMapPage(
                      busId: booking.busId,
                      routeId: booking.routeId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Simple View'),
              subtitle: const Text('Basic location tracking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationTrackingPage(busId: booking.busId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTicket(BuildContext context, Booking booking) async {
    // Check if booking is confirmed and for today or future
    if (booking.status != BookingStatus.confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only confirmed bookings can be scanned'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Navigate to QR scanner page
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentScanQRPage(booking: booking),
      ),
    );

    if (result == true && context.mounted) {
      // Ride started successfully, refresh bookings
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride started! Have a safe journey 🚌'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Widget for displaying individual booking card
class _BookingCard extends StatelessWidget {
  final Booking booking;
  final Bus? bus;
  final BusRoute? route;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onCancel;
  final VoidCallback onTrack;
  final VoidCallback onShowTicket;

  const _BookingCard({
    required this.booking,
    required this.bus,
    required this.route,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onCancel,
    required this.onTrack,
    required this.onShowTicket,
  });

  @override
  Widget build(BuildContext context) {
    final trackingStatus = _BookingUtils.getTrackingStatus(booking);
    final isUpcoming = _BookingUtils.isUpcoming(booking);

    return Card(
      elevation: isUpcoming ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isUpcoming
            ? BorderSide(color: AppTheme.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onToggleExpand,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUpcoming) _buildUpcomingBadge(),
              _buildHeader(context),
              if (!isExpanded) _buildCollapsedPreview(context),
              if (isExpanded) ...[
                const SizedBox(height: 16),
                _buildExpandedDetails(context),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                _buildActionButtons(context, trackingStatus),
                if (!trackingStatus.canTrack && booking.status == BookingStatus.confirmed)
                  _buildTrackingInfo(context, trackingStatus),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingBadge() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.access_time, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'UPCOMING',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                booking.busNumber,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _getStatusIcon(booking.status),
              size: 20,
              color: _getStatusColor(booking.status),
            ),
          ],
        ),
        Row(
          children: [
            _buildStatusBadge(booking.status),
            const SizedBox(width: 8),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.grey[600],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BookingStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1,
        ),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildCollapsedPreview(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (route != null)
          Text(
            route!.routeName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (booking.selectedBookingDate != null && booking.selectedTimeSlot != null) ...[
          const SizedBox(height: 4),
          Text(
            '${_BookingUtils.formatDate(booking.selectedBookingDate!)} at ${booking.selectedTimeSlot}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedDetails(BuildContext context) {
    return Column(
      children: [
        if (route != null) ...[
          _InfoRow(
            icon: Icons.route,
            label: 'Route',
            value: route!.routeName,
          ),
          const SizedBox(height: 8),
        ],
        _InfoRow(
          icon: Icons.location_on,
          label: 'From',
          value: booking.pickupLocation,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'To',
          value: booking.dropLocation,
        ),
        const SizedBox(height: 8),
        if (booking.selectedBookingDate != null) ...[
          _InfoRow(
            icon: Icons.calendar_today,
            label: 'Travel Date',
            value: _BookingUtils.formatDate(booking.selectedBookingDate!),
          ),
          const SizedBox(height: 8),
        ],
        if (booking.selectedTimeSlot != null) ...[
          _InfoRow(
            icon: Icons.access_time,
            label: 'Pickup Time',
            value: booking.selectedTimeSlot!,
          ),
          const SizedBox(height: 8),
        ],
        if (booking.seatNumber != null) ...[
          _InfoRow(
            icon: Icons.event_seat,
            label: 'Seat Number',
            value: booking.seatNumber!,
          ),
          const SizedBox(height: 8),
        ],
        if (booking.gender != null) ...[
          _InfoRow(
            icon: booking.gender?.toLowerCase() == 'male' 
                ? Icons.male 
                : Icons.female,
            label: 'Gender',
            value: booking.gender!,
          ),
          const SizedBox(height: 8),
        ],
        _InfoRow(
          icon: Icons.person,
          label: 'Driver',
          value: booking.driverName,
        ),
        const SizedBox(height: 8),
        _InfoRow(
          icon: Icons.phone,
          label: 'Contact',
          value: booking.driverPhone,
        ),
        if (booking.qrCode != null && booking.qrCode!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildQRCode(context),
        ],
      ],
    );
  }

  Widget _buildQRCode(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.qr_code_2,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Booking QR Code',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: QrImageView(
              data: booking.qrCode!,
              version: QrVersions.auto,
              size: 160.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Show this to the driver',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, TrackingStatus trackingStatus) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: trackingStatus.canTrack ? onTrack : null,
                icon: const Icon(Icons.map, size: 18),
                label: Text(
                  trackingStatus.buttonText,
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: trackingStatus.canTrack ? AppTheme.primaryColor : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            if (booking.status == BookingStatus.confirmed) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShowTicket,
                  icon: const Icon(Icons.qr_code, size: 18),
                  label: const Text(
                    'Scan QR',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (booking.status == BookingStatus.confirmed) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
            label: const Text(
              'Cancel Booking',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTrackingInfo(BuildContext context, TrackingStatus trackingStatus) {
    if (trackingStatus.infoMessage.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trackingStatus.infoMessage,
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(BookingStatus status) {
    switch (status) {
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.completed:
        return Icons.check_circle_outline;
    }
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
}

/// Info row widget for booking details
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey[600],
        ),
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
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Tracking status information
class TrackingStatus {
  final bool canTrack;
  final String buttonText;
  final String infoMessage;

  const TrackingStatus({
    required this.canTrack,
    required this.buttonText,
    required this.infoMessage,
  });
}

/// Utility methods for booking operations
class _BookingUtils {
  static DateTime? getBookingDateTime(Booking booking) {
    if (booking.selectedTimeSlot == null || booking.selectedBookingDate == null) {
      return null;
    }

    final timeSlot = booking.selectedTimeSlot!;
    final timeParts = timeSlot.split(' ');
    if (timeParts.length != 2) return null;

    final hourMinute = timeParts[0].split(':');
    if (hourMinute.length != 2) return null;

    int hour = int.tryParse(hourMinute[0]) ?? 0;
    final minute = int.tryParse(hourMinute[1]) ?? 0;
    final isPM = timeParts[1].toUpperCase() == 'PM';

    // Convert to 24-hour format
    if (isPM && hour != 12) {
      hour += 12;
    } else if (!isPM && hour == 12) {
      hour = 0;
    }

    return DateTime(
      booking.selectedBookingDate!.year,
      booking.selectedBookingDate!.month,
      booking.selectedBookingDate!.day,
      hour,
      minute,
    );
  }

  static bool isUpcoming(Booking booking) {
    if (booking.status != BookingStatus.confirmed) {
      return false;
    }

    final bookingDateTime = getBookingDateTime(booking);
    if (bookingDateTime == null) return false;

    final now = DateTime.now();
    final difference = bookingDateTime.difference(now);

    // Consider booking as upcoming if it's in the future and within next 24 hours
    return difference.inMinutes > 0 && difference.inHours <= 24;
  }

  static TrackingStatus getTrackingStatus(Booking booking) {
    // Only confirmed bookings can be tracked
    if (booking.status != BookingStatus.confirmed) {
      return const TrackingStatus(
        canTrack: false,
        buttonText: 'Not Available',
        infoMessage: '',
      );
    }

    final bookingDateTime = getBookingDateTime(booking);
    if (bookingDateTime == null) {
      return const TrackingStatus(
        canTrack: false,
        buttonText: 'Not Available',
        infoMessage: '',
      );
    }

    final now = DateTime.now();
    final difference = bookingDateTime.difference(now);

    // Enable tracking if within 15 minutes before or after the scheduled time
    if (difference.inMinutes <= 15 && difference.inMinutes >= -60) {
      return const TrackingStatus(
        canTrack: true,
        buttonText: 'Track Bus',
        infoMessage: '',
      );
    }

    // Trip completed
    if (difference.inMinutes < -60) {
      return const TrackingStatus(
        canTrack: false,
        buttonText: 'Trip Completed',
        infoMessage: '',
      );
    }

    // Too early to track
    final trackingAvailableAt = bookingDateTime.subtract(const Duration(minutes: 15));
    final timeUntilTracking = trackingAvailableAt.difference(now);

    String infoMessage;
    if (timeUntilTracking.inHours >= 24) {
      final days = timeUntilTracking.inDays;
      final hours = timeUntilTracking.inHours % 24;
      infoMessage = 'Tracking will be available in ${days}d ${hours}h';
    } else if (timeUntilTracking.inHours > 0) {
      final hours = timeUntilTracking.inHours;
      final minutes = timeUntilTracking.inMinutes % 60;
      infoMessage = 'Tracking will be available in ${hours}h ${minutes}m';
    } else {
      final minutes = timeUntilTracking.inMinutes;
      infoMessage = 'Tracking will be available in ${minutes}m';
    }

    return TrackingStatus(
      canTrack: false,
      buttonText: 'Not Yet Available',
      infoMessage: infoMessage,
    );
  }

  static String formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

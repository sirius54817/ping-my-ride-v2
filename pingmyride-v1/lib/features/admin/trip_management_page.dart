import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/services/trip_service.dart';
import '../../core/services/bus_service.dart';
import '../../core/models/trip.dart';
import '../../shared/widgets/custom_button.dart';

/// Trip Management Page - Admin can create and manage scheduled trips
class TripManagementPage extends StatefulWidget {
  const TripManagementPage({super.key});

  @override
  State<TripManagementPage> createState() => _TripManagementPageState();
}

class _TripManagementPageState extends State<TripManagementPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripService>(context, listen: false).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Management'),
      ),
      body: Consumer<TripService>(
        builder: (context, tripService, child) {
          if (tripService.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Scheduled Trips (${tripService.trips.length})',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddTripDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Create Trip'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tripService.trips.isEmpty
                    ? const Center(
                        child: Text(
                          'No trips scheduled yet.\nTap "Create Trip" to get started.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tripService.trips.length,
                        itemBuilder: (context, index) {
                          final trip = tripService.trips[index];
                          return _buildTripCard(context, trip);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTripCard(BuildContext context, Trip trip) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final isUpcoming = trip.tripDate.isAfter(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    color: isUpcoming ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    trip.busNumber,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    trip.routeName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete')
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditTripDialog(context, trip);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(context, trip);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Date: ${dateFormat.format(trip.tripDate)}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('Departure: ${trip.departureTime}'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.event_seat, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Seats: ${trip.availableSeats}/${trip.totalSeats} available',
                  style: TextStyle(
                    color: trip.hasAvailableSeats ? Colors.green : Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTripDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddTripDialog(),
    );
  }

  void _showEditTripDialog(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (context) => AddTripDialog(trip: trip),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Trip trip) {
    final tripService = Provider.of<TripService>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete this trip for ${trip.busNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await tripService.deleteTrip(trip.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Trip deleted successfully' : 'Failed to delete trip'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

/// Dialog to add or edit a trip
class AddTripDialog extends StatefulWidget {
  final Trip? trip;

  const AddTripDialog({super.key, this.trip});

  @override
  State<AddTripDialog> createState() => _AddTripDialogState();
}

class _AddTripDialogState extends State<AddTripDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBusId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      _selectedBusId = widget.trip!.busId;
      _selectedDate = widget.trip!.tripDate;
      // Parse time from trip
      final timeParts = widget.trip!.departureTime.split(':');
      if (timeParts.length >= 2) {
        final hour = int.tryParse(timeParts[0]) ?? 0;
        final minPart = timeParts[1].split(' ');
        final minute = int.tryParse(minPart[0]) ?? 0;
        _selectedTime = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.trip == null ? 'Create Trip' : 'Edit Trip'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bus selection
                Consumer<BusService>(
                  builder: (context, busService, child) {
                    return DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Select Bus',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_bus),
                      ),
                      initialValue: _selectedBusId,
                      items: busService.buses.map((bus) {
                        final route = busService.getRouteById(bus.routeId);
                        return DropdownMenuItem(
                          value: bus.id,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${bus.busNumber} - ${route?.routeName ?? 'Unknown Route'}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Capacity: ${bus.capacity} seats',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedBusId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a bus';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Date selection
                ListTile(
                  title: const Text('Trip Date'),
                  subtitle: Text(DateFormat('MMM dd, yyyy').format(_selectedDate)),
                  leading: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                ),
                const Divider(),
                // Time selection
                ListTile(
                  title: const Text('Departure Time'),
                  subtitle: Text(_selectedTime.format(context)),
                  leading: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (time != null) {
                      setState(() {
                        _selectedTime = time;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        CustomButton(
          text: widget.trip == null ? 'Create' : 'Update',
          onPressed: _isLoading ? () {} : _handleSubmit,
          isLoading: _isLoading,
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final tripService = Provider.of<TripService>(context, listen: false);
    final busService = Provider.of<BusService>(context, listen: false);
    
    final bus = busService.buses.firstWhere((b) => b.id == _selectedBusId);
    final route = busService.getRouteById(bus.routeId);

    bool success;
    final timeString = _selectedTime.format(context);

    if (widget.trip == null) {
      // Create new trip
      success = await tripService.addTrip(
        busId: bus.id,
        routeId: bus.routeId,
        busNumber: bus.busNumber,
        routeName: route?.routeName ?? '',
        tripDate: _selectedDate,
        departureTime: timeString,
        totalSeats: bus.capacity,
      );
    } else {
      // Update existing trip
      final updatedTrip = widget.trip!.copyWith(
        tripDate: _selectedDate,
        departureTime: timeString,
        updatedAt: DateTime.now(),
      );
      success = await tripService.updateTrip(updatedTrip);
    }

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? '${widget.trip == null ? 'Trip created' : 'Trip updated'} successfully'
              : 'Failed to ${widget.trip == null ? 'create' : 'update'} trip'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}

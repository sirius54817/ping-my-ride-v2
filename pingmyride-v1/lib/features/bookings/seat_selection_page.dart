import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/bus.dart';
import '../../core/models/bus_route.dart';
import '../../core/models/trip.dart';
import '../../core/models/seat.dart';

class SeatSelectionPage extends StatefulWidget {
  // Legacy constructor (for backward compatibility)
  final Bus? bus;
  final BusRoute? route;
  final String? selectedTimeSlot;
  final DateTime? selectedBookingDate;

  // New constructor fields (for trip-based booking)
  final Trip? trip;
  final String? boardingStop;
  final String? dropStop;
  final String? boardingTime;
  final String? dropTime;

  const SeatSelectionPage({
    super.key,
    this.bus,
    this.route,
    this.selectedTimeSlot,
    this.selectedBookingDate,
    this.trip,
    this.boardingStop,
    this.dropStop,
    this.boardingTime,
    this.dropTime,
  });

  @override
  State<SeatSelectionPage> createState() => _SeatSelectionPageState();
}

class _SeatSelectionPageState extends State<SeatSelectionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Seat> _seats = [];
  Seat? _selectedSeat;
  SeatGender? _userGender;
  bool _isLoading = true;
  
  // Bus layout configuration (2-2 seating)
  final int _seatsPerRow = 4;
  final int _totalRows = 10; // 40 seats total

  @override
  void initState() {
    super.initState();
    _initializeSeats();
  }

  Future<void> _initializeSeats() async {
    setState(() => _isLoading = true);

    try {
      // Generate seat layout
      final List<Seat> allSeats = [];
      int seatCounter = 1;

      for (int row = 0; row < _totalRows; row++) {
        for (int col = 0; col < _seatsPerRow; col++) {
          // Skip middle aisle (column 2)
          if (col == 2) continue;

          SeatType type;
          if (col == 0 || col == 3) {
            type = SeatType.window;
          } else {
            type = SeatType.aisle;
          }

          allSeats.add(Seat(
            seatNumber: 'S$seatCounter',
            type: type,
            row: row,
            column: col,
          ));
          seatCounter++;
        }
      }

      // Fetch booked seats for this bus/trip, time slot, and date
      final busId = widget.trip?.busId ?? widget.bus?.id;
      final bookingDate = widget.trip?.tripDate ?? widget.selectedBookingDate;
      final timeSlot = widget.trip?.departureTime ?? widget.selectedTimeSlot;

      if (bookingDate != null && timeSlot != null && busId != null) {
        final bookingsSnapshot = await _firestore
            .collection('bookings')
            .where('busId', isEqualTo: busId)
            .where('selectedTimeSlot', isEqualTo: timeSlot)
            .where('status', isEqualTo: 'confirmed')
            .get();

        for (var bookingDoc in bookingsSnapshot.docs) {
          final bookingData = bookingDoc.data();
          final bookingDateFromDb = (bookingData['selectedBookingDate'] as Timestamp?)?.toDate();
          
          if (bookingDateFromDb != null &&
              bookingDateFromDb.year == bookingDate.year &&
              bookingDateFromDb.month == bookingDate.month &&
              bookingDateFromDb.day == bookingDate.day) {
            
            final seatNumber = bookingData['seatNumber'] as String?;
            final gender = bookingData['gender'] as String?;
            final userId = bookingData['userId'] as String?;

            if (seatNumber != null) {
              final seatIndex = allSeats.indexWhere((s) => s.seatNumber == seatNumber);
              if (seatIndex != -1) {
                allSeats[seatIndex] = allSeats[seatIndex].copyWith(
                  isBooked: true,
                  bookedBy: gender == 'male' ? SeatGender.male : SeatGender.female,
                  userId: userId,
                );
              }
            }
          }
        }
      }

      setState(() {
        _seats = allSeats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _canSelectSeat(Seat seat) {
    if (seat.isBooked) return false;
    if (_userGender == null) return false;

    // Check adjacent seats for gender restrictions
    final adjacentSeats = _getAdjacentSeats(seat);
    
    for (final adjacentSeat in adjacentSeats) {
      if (adjacentSeat.isBooked && adjacentSeat.bookedBy != null) {
        // Opposite gender cannot sit beside each other
        if ((_userGender == SeatGender.male && adjacentSeat.bookedBy == SeatGender.female) ||
            (_userGender == SeatGender.female && adjacentSeat.bookedBy == SeatGender.male)) {
          return false;
        }
      }
    }

    return true;
  }

  List<Seat> _getAdjacentSeats(Seat seat) {
    final adjacent = <Seat>[];
    
    // Left seat (same row, column - 1)
    if (seat.column > 0) {
      final leftSeat = _seats.firstWhere(
        (s) => s.row == seat.row && s.column == seat.column - 1,
        orElse: () => seat,
      );
      if (leftSeat != seat) adjacent.add(leftSeat);
    }
    
    // Right seat (same row, column + 1)
    if (seat.column < _seatsPerRow - 1) {
      final rightSeat = _seats.firstWhere(
        (s) => s.row == seat.row && s.column == seat.column + 1,
        orElse: () => seat,
      );
      if (rightSeat != seat) adjacent.add(rightSeat);
    }

    return adjacent;
  }

  void _onSeatTap(Seat seat) {
    if (!_canSelectSeat(seat)) {
      String message = 'This seat cannot be selected';
      if (seat.isBooked) {
        message = 'This seat is already booked';
      } else if (_userGender == null) {
        message = 'Please select your gender first';
      } else {
        message = 'Cannot sit beside opposite gender';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    setState(() {
      _selectedSeat = seat;
    });
  }

  void _proceedToPayment() {
    if (_selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a seat')),
      );
      return;
    }

    if (_userGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    // Return selected seat info to previous screen
    Navigator.pop(context, {
      'seat': _selectedSeat,
      'gender': _userGender == SeatGender.male ? 'male' : 'female',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Seat'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Gender selection
                _buildGenderSelection(),
                
                // Legend
                _buildLegend(),
                
                const Divider(height: 1),
                
                // Seat map
                Expanded(
                  child: _buildSeatMap(),
                ),
                
                // Selected seat info & proceed button
                _buildBottomBar(),
              ],
            ),
    );
  }

  Widget _buildGenderSelection() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Your Gender',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildGenderOption(
                  'Male',
                  SeatGender.male,
                  Icons.male,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildGenderOption(
                  'Female',
                  SeatGender.female,
                  Icons.female,
                  Colors.pink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(String label, SeatGender gender, IconData icon, Color color) {
    final isSelected = _userGender == gender;
    
    return InkWell(
      onTap: () {
        setState(() {
          _userGender = gender;
          _selectedSeat = null; // Reset selection when gender changes
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem('Available', Colors.white, Colors.grey.shade400),
          _buildLegendItem('Male', Colors.blue.shade100, Colors.blue),
          _buildLegendItem('Female', Colors.pink.shade100, Colors.pink),
          _buildLegendItem('Selected', Colors.green.shade100, Colors.green),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color fillColor, Color borderColor) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSeatMap() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Driver section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.airline_seat_recline_extra, size: 20),
                SizedBox(width: 8),
                Text(
                  'Driver',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Seats grid
          ...List.generate(_totalRows, (rowIndex) => _buildSeatRow(rowIndex)),
        ],
      ),
    );
  }

  Widget _buildSeatRow(int rowIndex) {
    final rowSeats = _seats.where((seat) => seat.row == rowIndex).toList();
    rowSeats.sort((a, b) => a.column.compareTo(b.column));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Left side seats (columns 0, 1)
          ...rowSeats
              .where((seat) => seat.column < 2)
              .map((seat) => _buildSeatWidget(seat)),
          
          // Aisle
          const SizedBox(width: 40),
          
          // Right side seats (columns 3, 4)  
          ...rowSeats
              .where((seat) => seat.column >= 2)
              .map((seat) => _buildSeatWidget(seat)),
        ],
      ),
    );
  }

  Widget _buildSeatWidget(Seat seat) {
    Color fillColor;
    Color borderColor;
    bool isSelected = _selectedSeat?.seatNumber == seat.seatNumber;

    if (isSelected) {
      fillColor = Colors.green.shade100;
      borderColor = Colors.green;
    } else if (seat.isBooked) {
      if (seat.bookedBy == SeatGender.male) {
        fillColor = Colors.blue.shade100;
        borderColor = Colors.blue;
      } else {
        fillColor = Colors.pink.shade100;
        borderColor = Colors.pink;
      }
    } else {
      fillColor = Colors.white;
      borderColor = _canSelectSeat(seat) ? Colors.grey.shade400 : Colors.red.shade300;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: seat.isBooked ? null : () => _onSeatTap(seat),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: fillColor,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              // Seat number
              Center(
                child: Text(
                  seat.seatNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: seat.isBooked ? borderColor : Colors.black87,
                  ),
                ),
              ),
              // Window icon
              if (seat.type == SeatType.window)
                Positioned(
                  top: 2,
                  left: 2,
                  child: Icon(
                    Icons.window,
                    size: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedSeat != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Selected Seat:',
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    _selectedSeat!.seatNumber,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedSeat != null && _userGender != null
                    ? _proceedToPayment
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Proceed to Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

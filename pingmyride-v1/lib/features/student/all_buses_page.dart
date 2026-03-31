import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/bus.dart';
import '../../core/models/bus_route.dart';
import '../../core/services/bus_service.dart';
import '../../core/helpers/booking_flow_helper.dart';
import '../../shared/widgets/app_loading_indicator.dart';

class AllBusesPage extends StatefulWidget {
  const AllBusesPage({super.key});

  @override
  State<AllBusesPage> createState() => _AllBusesPageState();
}

class _AllBusesPageState extends State<AllBusesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showActiveOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Buses',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Active only',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
                Switch(
                  value: _showActiveOnly,
                  onChanged: (val) => setState(() => _showActiveOnly = val),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white38,
                  inactiveThumbColor: Colors.white54,
                  inactiveTrackColor: Colors.white24,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<BusService>(
        builder: (context, busService, _) {
          if (busService.isLoading) {
            return const AppLoadingIndicator(message: 'Loading buses...');
          }

          final routeById = {for (final route in busService.routes) route.id: route};
          var buses = busService.buses;
          if (_showActiveOnly) buses = buses.where((b) => b.isActive).toList();
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            buses = buses.where((b) {
              final route = routeById[b.routeId];
              return b.busNumber.toLowerCase().contains(q) ||
                  (route?.routeName.toLowerCase().contains(q) ?? false) ||
                  (route?.pickupLocation.toLowerCase().contains(q) ?? false) ||
                  (route?.dropLocation.toLowerCase().contains(q) ?? false);
            }).toList();
          }

          return Column(
            children: [
              // Search bar
              Container(
                color: primary,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by bus number or route…',
                    hintStyle: const TextStyle(color: Colors.white60),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.white70),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white70),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Count chip
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${buses.length} bus${buses.length == 1 ? '' : 'es'} found',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // List
              Expanded(
                child: buses.isEmpty
                    ? _buildEmptyState(context, primary)
                    : RefreshIndicator(
                        onRefresh: () => busService.fetchBuses(),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          cacheExtent: 800,
                          itemCount: buses.length,
                          itemBuilder: (context, index) {
                            final bus = buses[index];
                            final route = routeById[bus.routeId];
                            return _buildBusListTile(
                                context, bus, route, busService, primary);
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

  Widget _buildBusListTile(BuildContext context, Bus bus, BusRoute? route,
      BusService busService, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          bus.busNumber,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Active / Inactive badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: bus.isActive
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color:
                              bus.isActive ? Colors.green : Colors.redAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bus.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: bus.isActive
                                ? Colors.green
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                route?.routeName ?? 'Route not assigned',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              if (route != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.pickupLocation,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        size: 10, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        route.dropLocation,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      route.estimatedDuration,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.people, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '${bus.capacity} seats',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: bus.isActive
                      ? () => BookingFlowHelper.start(context, bus, route)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    bus.isActive ? 'Book Now' : 'Unavailable',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus_outlined,
              size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No buses match "$_searchQuery"'
                : 'No buses found',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.grey[500]),
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }
}

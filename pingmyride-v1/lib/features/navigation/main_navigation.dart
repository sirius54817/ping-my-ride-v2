import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/models/user_type.dart';
import '../../core/services/bus_service.dart';
import '../../core/services/auth_service.dart';
import '../home/home_page.dart';
import '../bookings/bookings_page.dart';
import '../admin/management_page.dart';
import '../admin/analytics_page.dart';
import '../profile/profile_page.dart';
import '../driver/driver_home_page.dart';
import '../driver/driver_route_page.dart';
import '../auth/login_page.dart';
import '../../shared/widgets/app_loading_indicator.dart';

class MainNavigation extends StatefulWidget {
  final UserType userType;

  const MainNavigation({super.key, required this.userType});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isVerifyingRole = true;
  bool _roleValid = false;

  @override
  void initState() {
    super.initState();
    _verifyUserRole();
  }

  /// Verify that the authenticated user's role matches the provided userType
  /// This prevents unauthorized access to other role dashboards
  Future<void> _verifyUserRole() async {
    try {
      // Skip Firebase verification for admin - admin uses hardcoded login
      if (widget.userType == UserType.admin) {
        if (mounted) {
          setState(() {
            _roleValid = true;
            _isVerifyingRole = false;
          });
        }
        return;
      }
      
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        // No authenticated user, redirect to login
        _redirectToLogin('Authentication required');
        return;
      }

      // Fetch user's actual role from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        _redirectToLogin('User data not found');
        return;
      }

      final userData = doc.data()!;
      final actualUserType = UserType.values.firstWhere(
        (type) => type.name == userData['userType'],
        orElse: () => UserType.student,
      );

      // Verify role matches
      if (actualUserType != widget.userType) {
        // Role mismatch - potential security issue
        await FirebaseAuth.instance.signOut();
        _redirectToLogin('Access denied: Invalid role');
        return;
      }

      // Role verified successfully
      if (mounted) {
        setState(() {
          _roleValid = true;
          _isVerifyingRole = false;
        });
      }
    } catch (e) {
      _redirectToLogin('Verification failed: $e');
    }
  }

  void _redirectToLogin(String message) {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  List<Widget> _getPages() {
    switch (widget.userType) {
      case UserType.student:
        return [
          HomePage(userType: widget.userType),
          const BookingsPage(),
          const SchedulePage(),
          const ProfilePage(),
        ];
      case UserType.driver:
        return [
          const DriverHomePage(),
          const RoutePage(),
          const StudentsPage(),
          const ProfilePage(),
        ];
      case UserType.admin:
        return [
          HomePage(userType: widget.userType),
          const ManagementPage(),
          const AnalyticsPage(),
          const ProfilePage(),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while verifying user role
    if (_isVerifyingRole) {
      return const Scaffold(
        body: AppLoadingIndicator(message: 'Verifying access...'),
      );
    }

    // Only show navigation if role is verified
    if (!_roleValid) {
      return const Scaffold(
        body: Center(
          child: Text('Access denied'),
        ),
      );
    }

    final pages = _getPages();
    
    // Prevent back navigation to login screen
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // Prevent navigation back to login screen
        if (didPop) return;
        // Show a message or do nothing - user cannot go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use logout button to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: _getNavDestinations(),
          animationDuration: const Duration(milliseconds: 400),
        ),
      ),
      ),
    );
  }

  List<NavigationDestination> _getNavDestinations() {
    switch (widget.userType) {
      case UserType.student:
        return const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number_rounded),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
      case UserType.driver:
        return const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route_rounded),
            label: 'Route',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            selectedIcon: Icon(Icons.group_rounded),
            label: 'Students',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
      case UserType.admin:
        return const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Manage',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded),
            label: 'Analytics',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
    }
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusService>(context, listen: false).fetchBusTimings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Schedule'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              await Provider.of<BusService>(context, listen: false).fetchBusTimings();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule refreshed'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh schedules',
          ),
        ],
      ),
      body: Consumer<BusService>(
        builder: (context, busService, child) {
          if (busService.isLoading) {
            return const AppLoadingIndicator(message: 'Loading schedule...');
          }

          if (busService.busTimings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No schedules available',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bus timings will appear here once set by admin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: busService.busTimings.length,
            itemBuilder: (context, index) {
              final timing = busService.busTimings[index];
              final bus = busService.getBusById(timing.busId);
              final route = busService.getRouteById(timing.routeId);
              
              return _buildScheduleCard(context, timing, bus, route);
            },
          );
        },
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, timing, bus, route) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    bus?.busNumber ?? 'N/A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route?.routeName ?? 'Unknown Route',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (bus != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Driver: ${bus.driverName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Timings',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            ...timing.timings.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.stopName,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    entry.time,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: timing.daysOfWeek.map<Widget>((day) => Text(
                      '${day.substring(0, 3)}${timing.daysOfWeek.last != day ? ',' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoutePage extends StatelessWidget {
  const RoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverRoutePage();
  }
}

class StudentsPage extends StatelessWidget {
  const StudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Students'),
        elevation: 0,
      ),
      body: Consumer<BusService>(builder: (context, busService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final driverEmail = authService.currentUser?.email;
        
        // Get driver's buses
        final driverBuses = busService.buses
            .where((bus) => bus.driverEmail == driverEmail && bus.isActive)
            .toList();

        if (busService.isLoading) {
          return const AppLoadingIndicator(message: 'Loading students...');
        }

        if (driverBuses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Bus Assigned',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact admin to get assigned to a bus',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        }

        // Get all bookings for driver's buses
        final allStudents = <String, Map<String, dynamic>>{};
        
        for (final bus in driverBuses) {
          final busBookings = busService.confirmedBookings
              .where((b) => b.busId == bus.id)
              .toList();
          
          for (final booking in busBookings) {
            if (!allStudents.containsKey(booking.userId)) {
              allStudents[booking.userId] = {
                'userId': booking.userId,
                'userName': booking.userName,
                'bookings': 1,
                'buses': {bus.busNumber},
              };
            } else {
              allStudents[booking.userId]!['bookings'] = 
                  (allStudents[booking.userId]!['bookings'] as int) + 1;
              (allStudents[booking.userId]!['buses'] as Set<String>)
                  .add(bus.busNumber);
            }
          }
        }

        final studentList = allStudents.values.toList();

        if (studentList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Students Yet',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Students who book your bus will appear here',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: studentList.length,
          itemBuilder: (context, index) {
            final student = studentList[index];
            final buses = student['buses'] as Set<String>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                title: Text(
                  student['userName'] as String? ?? student['userId'] as String,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${student['bookings']} booking(s) • ${buses.join(', ')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              ),
            );
          },
        );
      }),
    );
  }
}

// All pages moved to their respective feature folders
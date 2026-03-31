import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/theme_service.dart';
import '../../core/services/bus_service.dart';
import '../../core/models/user_type.dart';
import '../auth/login_page.dart';
import '../bookings/bookings_list_page.dart';
import '../admin/bus_timing_page.dart';
import '../admin/management_page.dart';
import '../admin/drivers_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    // Check if user is admin BEFORE attempting to fetch profile
    if (authService.currentUserType == UserType.admin) {
      // Admin user - set hardcoded profile data directly
      setState(() {
        _userProfile = {
          'name': 'TANNEERU CHANDRA SIDHARDHA',
          'email': authService.currentUserEmail ?? 'chandrasidhardhatanneeru@gmail.com',
          'phone': '7204940447',
          'userType': 'admin',
        };
        _isLoading = false;
      });
      return;
    }
    
    // For students and drivers - fetch from Firebase
    final profile = await authService.getCurrentUserProfile();
    setState(() {
      _userProfile = profile;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final themeService = Provider.of<ThemeService>(context);
    final busService = Provider.of<BusService>(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userName = _userProfile?['name'] ?? 'User';
    final userEmail = _userProfile?['email'] ?? authService.currentUserEmail ?? '';
    final userPhone = _userProfile?['phone'] ?? 'Not provided';
    final userType = authService.currentUserType ?? UserType.student;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Professional App Bar with gradient
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userType.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Profile Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Section
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Account Information Section
                  _buildSectionHeader(context, 'Account Information'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    [
                      _InfoItem(
                        icon: Icons.person_outline,
                        label: 'Full Name',
                        value: userName,
                        isEditable: userType != UserType.admin,
                        onTap: userType != UserType.admin 
                            ? () => _showEditDialog(context, 'name', userName)
                            : null,
                      ),
                      _InfoItem(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: userEmail,
                      ),
                      _InfoItem(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: userPhone,
                        isEditable: userType != UserType.admin,
                        onTap: userType != UserType.admin
                            ? () => _showEditDialog(context, 'phone', userPhone)
                            : null,
                      ),
                      _InfoItem(
                        icon: Icons.badge_outlined,
                        label: 'User Type',
                        value: userType.label,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Statistics Section (for students)
                  if (userType == UserType.student) ...[
                    _buildSectionHeader(context, 'My Statistics'),
                    const SizedBox(height: 12),
                    _buildStatsCard(context, busService),
                    const SizedBox(height: 24),
                  ],

                  // Statistics Section (for admins)
                  if (userType == UserType.admin) ...[
                    _buildSectionHeader(context, 'System Overview'),
                    const SizedBox(height: 12),
                    _buildAdminStatsCard(context, busService),
                    const SizedBox(height: 24),
                  ],

                  // Quick Actions (for admins)
                  if (userType == UserType.admin) ...[
                    _buildSectionHeader(context, 'Quick Actions'),
                    const SizedBox(height: 12),
                    _buildAdminQuickActions(context),
                    const SizedBox(height: 24),
                  ],

                  // Settings Section
                  _buildSectionHeader(context, 'Preferences'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(context, themeService),

                  const SizedBox(height: 24),

                  // App Information
                  _buildSectionHeader(context, 'About'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    context,
                    [
                      _InfoItem(
                        icon: Icons.info_outline,
                        label: 'Version',
                        value: '1.0.0',
                      ),
                      _InfoItem(
                        icon: Icons.help_outline,
                        label: 'Help & Support',
                        value: 'Contact Support',
                        onTap: () async {
                          final TextEditingController controller = TextEditingController();
                          final phone = '917204940447';
                          final authService = Provider.of<AuthService>(context, listen: false);
                          final userName = _userProfile?['name'] ?? 'User';
                          final userEmail = _userProfile?['email'] ?? authService.currentUserEmail ?? '';
                          final userPhone = _userProfile?['phone'] ?? 'Not provided';
                          final userType = authService.currentUserType?.label ?? 'Unknown';

                          final result = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Describe your issue'),
                                content: TextField(
                                  controller: controller,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter your issue here...',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, controller.text.trim()),
                                    child: const Text('Send'),
                                  ),
                                ],
                              );
                            },
                          );
                          if (result != null && result.isNotEmpty) {
                            final template = '''*🚨 App Issue Report*
*Issue Description:*
$result

*👤 User Details:*
*Name:* $userName
*Email:* $userEmail
*Phone:* $userPhone
*User Type:* $userType''';
                            final message = Uri.encodeComponent(template);
                            final whatsappUrl = 'https://wa.me/$phone?text=$message';
                            final uri = Uri.parse(whatsappUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open WhatsApp.')),
                              );
                            }
                          }
                        },
                      ),
                      _InfoItem(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Privacy Policy',
                        value: 'View Policy',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Privacy Policy - Coming soon')),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context, authService),
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Logout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }

  Widget _buildInfoCard(BuildContext context, List<_InfoItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: items.map((item) {
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              subtitle: Text(
                item.value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              trailing: item.onTap != null
                  ? Icon(
                      item.isEditable ? Icons.edit_outlined : Icons.chevron_right,
                      size: item.isEditable ? 18 : 24,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    )
                  : null,
              onTap: item.onTap,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, BusService busService) {
    final totalBookings = busService.userBookings;
    final activeBookings = busService.confirmedBookings;
    final cancelledBookings = busService.userBookings
        .where((b) => b.status.name == 'cancelled')
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsListPage(
                    title: 'All Bookings',
                    bookings: totalBookings,
                    accentColor: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildStatItem(
                  context,
                  icon: Icons.confirmation_number,
                  label: 'Total',
                  value: totalBookings.length.toString(),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsListPage(
                    title: 'Active Bookings',
                    bookings: activeBookings,
                    accentColor: Colors.green,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildStatItem(
                  context,
                  icon: Icons.check_circle_outline,
                  label: 'Active',
                  value: activeBookings.length.toString(),
                  color: Colors.green,
                ),
              ),
            ),
            Container(
              height: 40,
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingsListPage(
                    title: 'Cancelled Bookings',
                    bookings: cancelledBookings,
                    accentColor: Colors.red,
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _buildStatItem(
                  context,
                  icon: Icons.cancel_outlined,
                  label: 'Cancelled',
                  value: cancelledBookings.length.toString(),
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildAdminStatsCard(BuildContext context, BusService busService) {
    final totalBuses = busService.buses.length;
    final activeBuses = busService.buses.where((b) => b.isActive).length;
    final totalRoutes = busService.routes.length;
    final totalTimings = busService.busTimings.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.directions_bus,
                  label: 'Total Buses',
                  value: totalBuses.toString(),
                  color: Theme.of(context).colorScheme.primary,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                _buildStatItem(
                  context,
                  icon: Icons.check_circle,
                  label: 'Active Buses',
                  value: activeBuses.toString(),
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  icon: Icons.route,
                  label: 'Routes',
                  value: totalRoutes.toString(),
                  color: Colors.blue,
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Theme.of(context).dividerColor,
                ),
                _buildStatItem(
                  context,
                  icon: Icons.schedule,
                  label: 'Timings',
                  value: totalTimings.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminQuickActions(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  size: 20,
                  color: Colors.blue,
                ),
              ),
              title: const Text('Manage Buses'),
              subtitle: const Text('Add, edit or remove buses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagementPage(initialTab: 0),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.route,
                  size: 20,
                  color: Colors.green,
                ),
              ),
              title: const Text('Manage Routes'),
              subtitle: const Text('Configure bus routes and stops'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManagementPage(initialTab: 1),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.schedule,
                  size: 20,
                  color: Colors.orange,
                ),
              ),
              title: const Text('Bus Timings'),
              subtitle: const Text('Set up bus schedules and timings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BusTimingPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.people,
                  size: 20,
                  color: Colors.purple,
                ),
              ),
              title: const Text('View Drivers'),
              subtitle: const Text('See all registered drivers'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriversPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.refresh,
                  size: 20,
                  color: Colors.teal,
                ),
              ),
              title: const Text('Refresh Data'),
              subtitle: const Text('Reload all system data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final busService = Provider.of<BusService>(context, listen: false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Refreshing data...')),
                );
                await busService.initialize();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Data refreshed successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, ThemeService themeService) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  themeService.themeMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : Icons.light_mode,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              title: Text(
                'Theme Mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              subtitle: Text(
                themeService.themeMode == ThemeMode.dark ? 'Dark Mode' : 'Light Mode',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              trailing: Switch(
                value: themeService.themeMode == ThemeMode.dark,
                onChanged: (value) {
                  themeService.toggleTheme();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String field, String currentValue) {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${field == 'name' ? 'Name' : 'Phone'}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: field == 'name' ? 'Full Name' : 'Phone Number',
              hintText: field == 'name' ? 'Enter your full name' : 'Enter your phone number',
            ),
            keyboardType: field == 'phone' ? TextInputType.phone : TextInputType.name,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'This field cannot be empty';
              }
              if (field == 'phone' && value.trim().length < 10) {
                return 'Please enter a valid phone number';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context);
                await _updateUserProfile(context, field, controller.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _updateUserProfile(BuildContext context, String field, String value) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Prevent admin profile updates (admin data is hardcoded)
      if (authService.currentUserType == UserType.admin) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Admin profile cannot be edited'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      final user = authService.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({field: value});

        // Reload profile
        await _loadUserProfile();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${field == 'name' ? 'Name' : 'Phone'} updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      await authService.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }
}

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isEditable;

  _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isEditable = false,
  });
}

import 'package:staff_cleaning/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:staff_cleaning/screens/login_screen.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/main.dart';
import 'package:staff_cleaning/screens/staff_management_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/shift_management_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/attendance_tracking_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/notification_history_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/admin_report_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/profile_editing_screen.dart'; // Add this import
import 'package:staff_cleaning/screens/admin_settings_screen.dart'; // Add this import

class AppDrawer extends StatelessWidget {
  final UserRole userRole;
  const AppDrawer({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final User? user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          ),
          ListTile( // Home
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => MainScreen(userRole: userRole, userId: user?.uid, initialIndex: 0),
                ),
              );
            },
          ),
          if (userRole == UserRole.admin) ...[
            ListTile( // Staff Management
              leading: const Icon(Icons.people_alt_rounded),
              title: const Text('Staff Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StaffManagementScreen(),
                  ),
                );
              },
            ),
            ListTile( // Shift Management
              leading: const Icon(Icons.schedule),
              title: const Text('Shift Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShiftManagementScreen(),
                  ),
                );
              },
            ),
            ListTile( // Attendance Tracking
              leading: const Icon(Icons.fingerprint),
              title: const Text('Attendance Tracking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceTrackingScreen(),
                  ),
                );
              },
            ),
            ListTile( // Notification History
              leading: const Icon(Icons.notifications),
              title: const Text('Notification History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NotificationHistoryScreen(userRole: userRole, userId: user?.uid),
                  ),
                );
              },
            ),
            ListTile( // Admin Task Report
              leading: const Icon(Icons.report),
              title: const Text('Admin Task Report'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminReportScreen(),
                  ),
                );
              },
            ),
            ListTile( // Profile
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileEditingScreen(),
                  ),
                );
              },
            ),
            ListTile( // Settings
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminSettingsScreen(),
                  ),
                );
              },
            ),
          ],
          const Divider(),
          ListTile( // Logout
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await firebaseService.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}


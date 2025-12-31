import 'package:staff_cleaning/screens/audit_logs_screen.dart';
import 'package:staff_cleaning/screens/change_password_screen.dart';
import 'package:staff_cleaning/screens/staff_management_screen.dart';
import 'package:flutter/material.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: const Text('Change Password'),
            leading: const Icon(Icons.lock),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Role Management'),
            leading: const Icon(Icons.people),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StaffManagementScreen()),
              );
            },
          ),
          ListTile(
            title: const Text('Audit Logs'),
            leading: const Icon(Icons.history),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AuditLogsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

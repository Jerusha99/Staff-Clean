import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:flutter/material.dart';

class NotificationSendingScreen extends StatefulWidget {
  const NotificationSendingScreen({super.key});

  @override
  State<NotificationSendingScreen> createState() => _NotificationSendingScreenState();
}

class _NotificationSendingScreenState extends State<NotificationSendingScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String? _selectedUser;
  bool _sendToAll = true;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Notification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _sendToAll,
                  onChanged: (value) {
                    setState(() {
                      _sendToAll = value!;
                      if (_sendToAll) {
                        _selectedUser = null;
                      }
                    });
                  },
                ),
                const Text('Send to all staff'),
              ],
            ),
            if (!_sendToAll)
              StreamBuilder<List<AppUserData>>(
                stream: _firebaseService.getStaffMembers(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No staff members found.'));
                  }

                  final staffMembers = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedUser,
                    hint: const Text('Select a staff member'),
                    onChanged: (value) {
                      setState(() {
                        _selectedUser = value;
                      });
                    },
                    items: staffMembers.map((staff) {
                      return DropdownMenuItem<String>(
                        value: staff.uid,
                        child: Text(staff.email),
                      );
                    }).toList(),
                  );
                },
              ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final title = _titleController.text;
                final body = _bodyController.text;

                if (title.isEmpty || body.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Title and body cannot be empty.')),
                  );
                  return;
                }

                await _firebaseService.sendNotification(
                  title: title,
                  body: body,
                  userId: _sendToAll ? null : _selectedUser,
                );

                if (mounted) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Notification sent successfully!')),
                  );
                }
              },
              child: const Text('Send Notification'),
            ),
          ],
        ),
      ),
    );
  }
}

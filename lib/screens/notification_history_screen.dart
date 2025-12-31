import 'package:flutter/material.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/models/user_role.dart';

class NotificationHistoryScreen extends StatelessWidget {
  final UserRole userRole;
  final String? userId;

  const NotificationHistoryScreen({super.key, required this.userRole, this.userId});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    return Scaffold(
      appBar: AppBar(
        title: Text(userRole == UserRole.admin ? 'Notification History' : 'My Notifications'),
        actions: [
          if (userRole == UserRole.admin)
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                Navigator.pushNamed(context, '/send_notification');
              },
              tooltip: 'Send Notification',
            ),
        ],
      ),
      body: StreamBuilder<List<dynamic>>(
        stream: userRole == UserRole.admin
            ? firebaseService.getNotificationRequests()
            : firebaseService.getNotificationsForUser(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    userRole == UserRole.admin ? Icons.notifications_off : Icons.mail_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userRole == UserRole.admin 
                        ? 'No notification history found.'
                        : 'No notifications received.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh logic would be handled by the stream builder
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                
                // Handle different notification types
                String title, message, target;
                DateTime timestamp;
                bool isRead = false;

                if (userRole == UserRole.admin) {
                  // Admin view - notification requests
                  title = notification['title'] ?? 'No Title';
                  message = notification['body'] ?? 'No Message';
                  target = notification['userId'] ?? 'All Staff';
                  timestamp = notification['createdAt'] != null
                      ? DateTime.fromMillisecondsSinceEpoch(notification['createdAt'])
                      : DateTime.now();
                } else {
                  // Staff view - personal notifications
                  title = notification.title ?? 'No Title';
                  message = notification.message ?? 'No Message';
                  target = 'You';
                  timestamp = notification.timestamp;
                  isRead = notification.read ?? false;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: isRead ? 1 : 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: isRead ? Colors.grey[50] : Colors.white,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: isRead ? Colors.grey[300] : Theme.of(context).primaryColor,
                      child: Icon(
                        userRole == UserRole.admin ? Icons.send : Icons.notifications,
                        color: isRead ? Colors.grey[600] : Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isRead ? Colors.grey[600] : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.people,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              target,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: userRole == UserRole.staff && !isRead
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () {
                              firebaseService.markNotificationAsRead(notification.id);
                            },
                            tooltip: 'Mark as read',
                          )
                        : null,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(title),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(message),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    const Icon(Icons.people, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Sent to: $target'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 16),
                                    const SizedBox(width: 8),
                                    Text('Sent: ${_formatFullTimestamp(timestamp)}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          actions: [
                             if (userRole == UserRole.staff && !isRead)
                              TextButton(
                                onPressed: () {
                                  firebaseService.markNotificationAsRead(notification.id);
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Mark as Read'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFullTimestamp(DateTime timestamp) {
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} at ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

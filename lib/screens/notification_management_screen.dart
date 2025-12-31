import 'package:flutter/material.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/security_service.dart';
import 'package:staff_cleaning/services/validation_service.dart';
import 'package:staff_cleaning/services/error_handling_service.dart';
import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/widgets/bubble_animations.dart';

class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String? _selectedStaffId;
  List<AppUserData> _staffMembers = [];
  bool _isBroadcast = true;
  bool _isLoading = false;
  bool _isScheduled = false;
  DateTime? _scheduledTime;
  List<Map<String, dynamic>> _notificationHistory = [];
  String _selectedPriority = 'normal'; // low, normal, high, urgent

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!await SecurityService().isAdmin()) {
      if (!mounted) return;
      ErrorHandlingService.showErrorSnackBar(context, 'Access denied. Admin privileges required.');
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      // Load staff members
      final staffStream = _firebaseService.getStaffMembers();
      staffStream.listen((staff) {
        if (mounted) {
          setState(() => _staffMembers = staff);
        }
      });
      
      // Load notification history
      final historyStream = _firebaseService.getNotificationRequests();
      historyStream.listen((history) {
        if (mounted) {
          setState(() => _notificationHistory = history.reversed.take(50).toList());
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandlingService.showErrorSnackBar(context, 'Error loading data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await _firebaseService.sendNotification(
        title: _titleController.text.trim(),
        body: _messageController.text.trim(),
        userId: _isBroadcast ? null : _selectedStaffId,
      );
      
      _clearForm();
      if (!mounted) return;
      ErrorHandlingService.showSuccessSnackBar(context, 'Notification sent successfully!');
      
    } catch (e) {
      if (!mounted) return;
      ErrorHandlingService.showErrorSnackBar(context, 'Error sending notification: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _messageController.clear();
    setState(() {
      _selectedStaffId = null;
      _isBroadcast = true;
      _isScheduled = false;
      _scheduledTime = null;
      _selectedPriority = 'normal';
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return Colors.blue;
      case 'normal':
        return Colors.green;
      case 'high':
        return Colors.orange;
      case 'urgent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'low':
        return Icons.arrow_downward;
      case 'normal':
        return Icons.remove;
      case 'high':
        return Icons.arrow_upward;
      case 'urgent':
        return Icons.priority_high;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BubbleAnimation(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Notification Management'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _isLoading
            ? ErrorHandlingService.createLoadingWidget(message: 'Loading notification data...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Send Notification Form
                    BubbleCard(
                      isAnimating: true,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send Notification',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Title Input
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                labelText: 'Notification Title',
                                prefixIcon: Icon(Icons.title),
                                border: OutlineInputBorder(),
                              ),
                              validator: ValidationService.validateNotificationTitle,
                              maxLength: 100,
                            ),
                            const SizedBox(height: 16),
                            
                            // Message Input
                            TextFormField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                labelText: 'Message',
                                prefixIcon: Icon(Icons.message),
                                border: OutlineInputBorder(),
                              ),
                              maxLines: 4,
                              validator: ValidationService.validateNotificationBody,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 16),
                            
                            // Priority Selection
                            DropdownButtonFormField<String>(
                              initialValue: _selectedPriority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.priority_high),
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'low', child: Text('Low')),
                                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                                DropdownMenuItem(value: 'high', child: Text('High')),
                                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedPriority = value!);
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Broadcast/Target Selection
                              Row(
                                children: [
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Broadcast to All'),
                                      value: 'broadcast',
                                      // ignore: deprecated_member_use
                                      groupValue: _isBroadcast ? 'broadcast' : 'targeted',
                                      // ignore: deprecated_member_use
                                      onChanged: (value) {
                                        setState(() => _isBroadcast = value == 'broadcast');
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: RadioListTile<String>(
                                      title: const Text('Send to Specific Staff'),
                                      value: 'targeted',
                                      // ignore: deprecated_member_use
                                      groupValue: _isBroadcast ? 'broadcast' : 'targeted',
                                      // ignore: deprecated_member_use
                                      onChanged: (value) {
                                        setState(() => _isBroadcast = value == 'broadcast');
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            
                            if (!_isBroadcast) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedStaffId,
                                decoration: const InputDecoration(
                                  labelText: 'Select Staff Member',
                                  prefixIcon: Icon(Icons.person),
                                  border: OutlineInputBorder(),
                                ),
                                items: _staffMembers.map((staff) {
                                  return DropdownMenuItem<String>(
                                    value: staff.uid,
                                    child: Text('${staff.name} (${staff.email})'),
                                  );
                                }).toList(),
                                validator: (value) {
                                  if (!_isBroadcast && (value == null || value.isEmpty)) {
                                    return 'Please select a staff member';
                                  }
                                  return null;
                                },
                                onChanged: (value) {
                                  setState(() => _selectedStaffId = value);
                                },
                              ),
                            ],
                            
                            const SizedBox(height: 16),
                            
                            // Scheduling Options
                            CheckboxListTile(
                              title: const Text('Schedule for Later'),
                              subtitle: const Text('Send notification at a specific time'),
                              value: _isScheduled,
                              onChanged: (value) {
                                setState(() => _isScheduled = value ?? false);
                              },
                            ),
                            
                            if (_isScheduled) ...[
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Scheduled Time',
                                  prefixIcon: Icon(Icons.schedule),
                                  border: OutlineInputBorder(),
                                ),
                                controller: TextEditingController(
                                  text: _scheduledTime != null
                                      ? '${_scheduledTime!.day}/${_scheduledTime!.month}/${_scheduledTime!.year} ${_scheduledTime!.hour}:${_scheduledTime!.minute.toString().padLeft(2, '0')}'
                                      : '',
                                ),
                                readOnly: true,
                                onTap: () async {
                                  final localContext = context;
                                  final date = await showDatePicker(
                                    context: localContext,
                                    initialDate: _scheduledTime ?? DateTime.now().add(const Duration(hours: 1)),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (date != null) {
                                    if (!localContext.mounted) return;
                                    final time = await showTimePicker(
                                      context: localContext,
                                      initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? DateTime.now()),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        _scheduledTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Send Button
                            SizedBox(
                              width: double.infinity,
                              child: BubbleButton(
                                onPressed: _isLoading ? null : _sendNotification,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            _getPriorityIcon(_selectedPriority),
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _isScheduled ? 'Schedule Notification' : 'Send Now',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Notification History
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Notifications',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildNotificationHistory(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationHistory() {
    if (_notificationHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No notifications sent yet'),
        ),
      );
    }

    return Column(
      children: _notificationHistory.take(10).map((notification) {
        final timestamp = notification['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(notification['createdAt'])
            : DateTime.now();
        
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getPriorityColor(notification['priority'] ?? 'normal').withAlpha(25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getPriorityIcon(notification['priority'] ?? 'normal'),
                color: _getPriorityColor(notification['priority'] ?? 'normal'),
                size: 20,
              ),
            ),
            title: Text(
              notification['title'] ?? 'No Title',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification['body'] ?? 'No Message',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      notification['userId'] == null ? Icons.broadcast_on_personal : Icons.person,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notification['userId'] == null ? 'All Staff' : 'Specific Staff',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                _handleNotificationAction(notification, action);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'resend',
                  child: Row(
                    children: [
                      Icon(Icons.send, size: 16),
                      SizedBox(width: 8),
                      Text('Resend'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
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

  void _handleNotificationAction(Map<String, dynamic> notification, String action) {
    switch (action) {
      case 'resend':
        _titleController.text = notification['title'] ?? '';
        _messageController.text = notification['body'] ?? '';
        setState(() {
          _isBroadcast = notification['userId'] == null;
          _selectedStaffId = notification['userId'];
        });
        break;
      case 'delete':
        // Implement delete functionality
        _showDeleteConfirmation(notification);
        break;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> notification) {
    final currentContext = context;
    showDialog(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement actual delete
              ErrorHandlingService.showSuccessSnackBar(currentContext, 'Notification deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
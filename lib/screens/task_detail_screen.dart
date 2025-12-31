import 'package:staff_cleaning/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/services/firebase_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final CleaningTask task;
  final UserRole userRole;
  final String? userId;

  const TaskDetailScreen({super.key, required this.task, required this.userRole, this.userId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.task.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDetailRow(context, Icons.category, 'Area', widget.task.area.toString().split('.').last),
                    _buildDetailRow(context, Icons.calendar_today, 'Due Date', widget.task.dueDate.toLocal().toString().split(' ')[0]),
                    _buildDetailRow(context, Icons.repeat, 'Frequency', widget.task.frequency.toString().split('.').last),
                    _buildDetailRow(context, Icons.person, 'Assigned To', widget.task.assignedTo),
                    _buildDetailRow(context, Icons.person_add, 'Created By', widget.task.creatorName),
                  ],
                ),
              ),
            ),
            if (widget.userRole == UserRole.staff) ...[
              const SizedBox(height: 20),
              if (widget.task.status != CleaningStatus.completed)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      final updates = {
                        'status': CleaningStatus.completed.toString().split('.').last,
                      };
                      await _firebaseService.updateTask(widget.task.id, updates);
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Task marked as completed!')),
                        );
                        navigator.pop();
                      }
                    },
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Mark as Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                )
              else
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 30),
                        SizedBox(width: 10),
                        Text('Task already completed!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
            if (widget.task.proofOfWorkUrl != null) ...[
              const SizedBox(height: 20),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proof of Work', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Image.network(widget.task.proofOfWorkUrl!),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
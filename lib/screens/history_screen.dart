import 'package:staff_cleaning/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/screens/tasks_screen.dart'; // For TaskCard
import 'package:staff_cleaning/utils/theme.dart';

class HistoryScreen extends StatelessWidget {
  final UserRole userRole;
  final String? userId;

  const HistoryScreen({super.key, required this.userRole, this.userId});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: StreamBuilder<List<CleaningTask>>(
        stream: userRole == UserRole.admin
            ? firebaseService.getTasks()
            : firebaseService.getStaffTasks(userId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No tasks found.'));
          }

          final completedTasks = snapshot.data!
              .where((task) => task.status == CleaningStatus.completed)
              .toList();

          if (completedTasks.isEmpty) {
            return const Center(child: Text('No completed tasks found.'));
          }

          return ListView.builder(
            itemCount: completedTasks.length,
            itemBuilder: (context, index) {
              final task = completedTasks[index];
              return TaskCard(
                task: task,
                userRole: userRole,
                userId: userId,
                onDismissed: () {
                  // No dismiss action in history
                },
              );
            },
          );
        },
      ),
    );
  }
}

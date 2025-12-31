import 'package:staff_cleaning/models/user_role.dart';
import 'package:staff_cleaning/screens/chatbot_screen.dart';
import 'package:staff_cleaning/screens/notification_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/models/recurring_task.dart';
import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/models/shift.dart';
import 'package:staff_cleaning/models/app_notification.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/task_scheduling_service.dart';
import 'package:staff_cleaning/services/error_handling_service.dart';
import 'package:staff_cleaning/widgets/issue_reporting_dialog.dart';
import 'package:staff_cleaning/widgets/bubble_animations.dart';
import 'package:staff_cleaning/screens/tasks_screen.dart';
import 'package:staff_cleaning/models/attendance.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:fl_chart/fl_chart.dart';


class DashboardScreen extends StatelessWidget {
  final UserRole userRole;
  final String? userId;
  final String userName;
  final String userEmail;

  const DashboardScreen({
    super.key,
    required this.userRole,
    this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return userRole == UserRole.admin
        ? AdminDashboard(userId: userId, userName: userName, userEmail: userEmail)
        : StaffDashboard(userId: userId!, userName: userName, userEmail: userEmail, userRole: userRole);
  }
}

enum TimePeriod { daily, weekly, monthly, annually }

class AdminDashboard extends StatefulWidget {
  final String? userId;
  final String userName;
  final String userEmail;

  const AdminDashboard({
    super.key,
    this.userId,
    required this.userName,
    required this.userEmail,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  TimePeriod _selectedPeriod = TimePeriod.daily;

  List<CleaningTask> _filterTasksByPeriod(List<CleaningTask> tasks, TimePeriod period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case TimePeriod.daily:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.weekly:
        final daysFromMonday = (now.weekday - 1) % 7;
        startDate = now.subtract(Duration(days: daysFromMonday));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case TimePeriod.monthly:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case TimePeriod.annually:
        startDate = DateTime(now.year, 1, 1);
        break;
    }

    return tasks.where((task) => task.dueDate.isAfter(startDate) || task.dueDate.isAtSameMomentAs(startDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    return StreamBuilder<AppUserData?>(
      stream: firebaseService.getUserDataStream(widget.userId ?? ''),
      builder: (context, userSnapshot) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,

          body: StreamBuilder<List<CleaningTask>>(
            stream: firebaseService.getTasks(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return ErrorHandlingService.createLoadingWidget(message: 'Loading dashboard...');
              }
              if (taskSnapshot.hasError) {
                return ErrorHandlingService.createErrorWidget(
                  message: 'Error loading tasks: ${taskSnapshot.error}',
                  onRetry: () => setState(() {}),
                );
              }
              final allTasks = taskSnapshot.data ?? [];
              assert(() {
                // Debug-only logs; stripped in release builds.
                // ignore: avoid_print
                print('Total tasks fetched: \'${allTasks.length}\'');
                return true;
              }());
              allTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
              final tasks = _filterTasksByPeriod(allTasks, _selectedPeriod);
              assert(() {
                // ignore: avoid_print
                print('Tasks after filtering for ${_selectedPeriod.name}: ${tasks.length}');
                return true;
              }());

              return StreamBuilder<List<AppUserData>>(
                stream: firebaseService.getStaffMembers(),
                builder: (context, staffSnapshot) {
                  if (staffSnapshot.connectionState == ConnectionState.waiting) {
                    return ErrorHandlingService.createLoadingWidget(message: 'Loading staff data...');
                  }
                  if (staffSnapshot.hasError) {
                    return ErrorHandlingService.createErrorWidget(
                      message: 'Error loading staff: ${staffSnapshot.error}',
                      onRetry: () => setState(() {}),
                    );
                  }
                  final staffMembers = staffSnapshot.data ?? [];

                  return CustomScrollView(
                    slivers: [
                      // MainScreen already provides the app bar for this tab,
                      // so we keep the scroll content clean here.
                      const SliverToBoxAdapter(
                        child: SizedBox.shrink(),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Section with Animation
                              BubbleCard(
                                isAnimating: true,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.dashboard,
                                          color: AppTheme.primaryColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Admin Dashboard',
                                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryColor,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Manage your cleaning operations efficiently',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Metrics Grid with Bubble Cards
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
                                  // Use a taller aspect ratio to avoid overflow inside cards.
                                  final childAspectRatio = constraints.maxWidth > 600 ? 1.0 : 0.9;

                                  return GridView.count(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: childAspectRatio,
                                    children: [
                                      StreamBuilder<int>(
                                        stream: firebaseService.getTasksCount(),
                                        builder: (context, snap) => buildAnimatedMetricCard(
                                          context,
                                          'Total Tasks',
                                          (snap.data ?? 0).toString(),
                                          Icons.assignment,
                                          AppTheme.primaryColor,
                                        ),
                                      ),
                                      StreamBuilder<int>(
                                        stream: firebaseService.getTasksCountByStatus(CleaningStatus.pending),
                                        builder: (context, snap) => buildAnimatedMetricCard(
                                          context,
                                          'Pending Tasks',
                                          (snap.data ?? 0).toString(),
                                          Icons.pending_actions,
                                          AppTheme.warningColor,
                                        ),
                                      ),
                                      StreamBuilder<int>(
                                        stream: firebaseService.getTasksCountByStatus(CleaningStatus.completed),
                                        builder: (context, snap) => buildAnimatedMetricCard(
                                          context,
                                          'Completed Tasks',
                                          (snap.data ?? 0).toString(),
                                          Icons.check_circle,
                                          AppTheme.successColor,
                                        ),
                                      ),
                                      StreamBuilder<int>(
                                        stream: firebaseService.getStaffCount(),
                                        builder: (context, snap) => buildAnimatedMetricCard(
                                          context,
                                          'Total Staff',
                                          (snap.data ?? 0).toString(),
                                          Icons.people,
                                          AppTheme.accentColor,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 30),

                              // Analytics Section
                              BubbleCard(
                                isAnimating: true,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Task Analytics',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.primaryColor.withAlpha(76)),
                                      ),
                                      child: DropdownButton<TimePeriod>(
                                        value: _selectedPeriod,
                                        underline: const SizedBox(),
                                        items: TimePeriod.values.map((period) {
                                          return DropdownMenuItem<TimePeriod>(
                                            value: period,
                                            child: Text(period.name.toUpperCase()),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedPeriod = value;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Charts with Bubble Cards
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  if (constraints.maxWidth > 800) {
                                    // Desktop layout: side by side
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: BubbleCard(
                                            isAnimating: true,
                                            child: TaskStatusPieChart(tasks: tasks),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: BubbleCard(
                                            isAnimating: true,
                                            child: TasksPerAreaBarChart(tasks: tasks),
                                          ),
                                        ),
                                      ],
                                    );
                                  } else {
                                    // Mobile layout: stacked
                                    return Column(
                                      children: [
                                        BubbleCard(
                                          isAnimating: true,
                                          child: TaskStatusPieChart(tasks: tasks),
                                        ),
                                        const SizedBox(height: 16),
                                        BubbleCard(
                                          isAnimating: true,
                                          child: TasksPerAreaBarChart(tasks: tasks),
                                        ),
                                      ],
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingBubble(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
            backgroundColor: AppTheme.secondaryColor,
            child: const Icon(Icons.chat, color: Colors.white),
          ),
        );
      },
    );
  }
}

class StaffDashboard extends StatefulWidget {
  final String userId;
  final String userName;
  final String userEmail;
  final UserRole userRole;

  const StaffDashboard({
    super.key,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userRole,
  });

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  TimePeriod _selectedPeriod = TimePeriod.daily;
  final TaskSchedulingService _taskSchedulingService = TaskSchedulingService();

  List<CleaningTask> _filterTasksByPeriod(List<CleaningTask> tasks, TimePeriod period) {
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case TimePeriod.daily:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.weekly:
        final daysFromMonday = (now.weekday - 1) % 7;
        startDate = now.subtract(Duration(days: daysFromMonday));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case TimePeriod.monthly:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case TimePeriod.annually:
        startDate = DateTime(now.year, 1, 1);
        break;
    }

    return tasks.where((task) => task.dueDate.isAfter(startDate) || task.dueDate.isAtSameMomentAs(startDate)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();
    final now = DateTime.now();
    final greeting = _getGreeting(now);

    return StreamBuilder<AppUserData?>(
      stream: firebaseService.getUserDataStream(widget.userId),
      builder: (context, userSnapshot) {
        final currentUserName = userSnapshot.data?.name ?? widget.userName;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false, // Prevent Flutter from adding a leading menu button.
          ),
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: <Widget>[
                DrawerHeader(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                  ),
                  child: Text(
                    'Staff Menu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
                // Other drawer items can be added here
              ],
            ),
          ),
          body: StreamBuilder<List<CleaningTask>>(
            stream: firebaseService.getStaffTasks(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState(context);
              }

              final allTasks = snapshot.data!;
              allTasks.sort((a, b) => b.dueDate.compareTo(a.dueDate));
              final tasks = _filterTasksByPeriod(allTasks, _selectedPeriod);
              final pendingTasks = allTasks.where((task) => task.status == CleaningStatus.pending).length;
              final inProgressTasks = allTasks.where((task) => task.status == CleaningStatus.inProgress).length;

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: AppTheme.primaryColor,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Welcome Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withAlpha(25),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    _getGreetingIcon(now),
                                    color: AppTheme.primaryColor,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$greeting, $currentUserName!',
                                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Ready to make today shine?',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Quick Stats
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildQuickStatCard(
                                'Today\'s Tasks',
                                pendingTasks.toString(),
                                Icons.today_rounded,
                                AppTheme.warningColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildQuickStatCard(
                                'In Progress',
                                inProgressTasks.toString(),
                                Icons.pending_rounded,
                                AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Status Cards
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildShiftCard(context, firebaseService),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildAttendanceCard(context, firebaseService),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Recurring Tasks
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: _buildRecurringTasksSection(),
                      ),
                    ),

                    // Recent Notifications
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          elevation: 0,
                          color: AppTheme.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor.withAlpha(25),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.notifications_rounded,
                                            color: AppTheme.primaryColor,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Recent Notifications',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => NotificationHistoryScreen(
                                              userRole: UserRole.staff,
                                              userId: widget.userId,
                                            ),
                                          ),
                                        );
                                      },
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppTheme.primaryColor,
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      child: const Text('View All'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildRecentNotifications(context, firebaseService),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Priority Tasks
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Card(
                          elevation: 0,
                          color: AppTheme.warningColor.withAlpha(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: AppTheme.warningColor.withAlpha(51), width: 1),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.priority_high_rounded,
                                        color: AppTheme.warningColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Priority Tasks',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildPriorityTasks(context, allTasks),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.secondaryColor.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.analytics_rounded,
                                        color: AppTheme.secondaryColor,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Performance Analytics',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: DropdownButton<TimePeriod>(
                                    value: _selectedPeriod,
                                    underline: const SizedBox(),
                                    isDense: true,
                                    style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    items: TimePeriod.values.map((period) {
                                      return DropdownMenuItem<TimePeriod>(
                                        value: period,
                                        child: Text(
                                          period.name.toUpperCase(),
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedPeriod = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth > 600) {
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Card(
                                          elevation: 0,
                                          color: AppTheme.surfaceColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                                          ),
                                          child: TaskStatusPieChart(tasks: tasks),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Card(
                                          elevation: 0,
                                          color: AppTheme.surfaceColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: BorderSide(color: Colors.grey.shade200, width: 1),
                                          ),
                                          child: TasksPerAreaBarChart(tasks: tasks),
                                        ),
                                      ),
                                    ],
                                  );
                                } else {
                                  return Column(
                                    children: [
                                      Card(
                                        elevation: 0,
                                        color: AppTheme.surfaceColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                                        ),
                                        child: TaskStatusPieChart(tasks: tasks),
                                      ),
                                      const SizedBox(height: 16),
                                      Card(
                                        elevation: 0,
                                        color: AppTheme.surfaceColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          side: BorderSide(color: Colors.grey.shade200, width: 1),
                                        ),
                                        child: TasksPerAreaBarChart(tasks: tasks),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom spacing
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 100),
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'fab_report_issue',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => IssueReportingDialog(
                      userId: widget.userId,
                      userName: currentUserName,
                    ),
                  );
                },
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.report_problem_rounded),
              ),
              const SizedBox(height: 12),
              FloatingActionButton(
                heroTag: 'fab_chatbot',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                  );
                },
                backgroundColor: AppTheme.secondaryColor,
                child: const Icon(Icons.chat_rounded),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getGreeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _getGreetingIcon(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return Icons.wb_sunny;
    if (hour < 17) return Icons.wb_cloudy;
    return Icons.nightlight_round;
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading your tasks...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load tasks',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withAlpha(25),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.assignment_turned_in_rounded,
                size: 64,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No tasks assigned yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Check back later for new assignments',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(BuildContext context, FirebaseService firebaseService) {
    return StreamBuilder<List<Shift>>(
      stream: firebaseService.getStaffShifts(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildStatusCard(
            'Today\'s Shift',
            'Loading...',
            Icons.schedule_rounded,
            AppTheme.primaryColor,
            false,
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildStatusCard(
            'Today\'s Shift',
            'No shift scheduled',
            Icons.event_busy_rounded,
            AppTheme.textLight,
            false,
          );
        }

        final shifts = snapshot.data!;
        final today = DateTime.now();
        final currentShift = shifts.firstWhere(
          (shift) =>
          shift.startTime.year == today.year &&
          shift.startTime.month == today.month &&
          shift.startTime.day == today.day,
          orElse: () => Shift(
            id: '',
            userId: widget.userId,
            userName: widget.userName,
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          ),
        );

        if (currentShift.id.isEmpty) {
          return _buildStatusCard(
            'Today\'s Shift',
            'No shift scheduled',
            Icons.event_busy_rounded,
            AppTheme.textLight,
            false,
          );
        }

        final shiftTime =
            '${currentShift.startTime.hour.toString().padLeft(2, '0')}:${currentShift.startTime.minute.toString().padLeft(2, '0')} - ${currentShift.endTime.hour.toString().padLeft(2, '0')}:${currentShift.endTime.minute.toString().padLeft(2, '0')}';
        return _buildStatusCard(
          'Today\'s Shift',
          shiftTime,
          Icons.schedule_rounded,
          AppTheme.primaryColor,
          false,
        );
      },
    );
  }

  Widget _buildAttendanceCard(BuildContext context, FirebaseService firebaseService) {
    return StreamBuilder<Attendance?>(
      stream: firebaseService.getDailyAttendance(widget.userId, DateTime.now()),
      builder: (context, snapshot) {
        final attendance = snapshot.data;
        final isCheckedIn = attendance != null;
        final isCheckedOut = attendance != null && attendance.checkOutTime != null;

        String status;
        IconData icon;
        Color color;
        bool isInteractive = true;

        if (isCheckedOut) {
          status = 'Checked Out';
          icon = Icons.check_circle_rounded;
          color = AppTheme.successColor;
          isInteractive = false;
        } else if (isCheckedIn) {
          status = 'Checked In';
          icon = Icons.login_rounded;
          color = AppTheme.warningColor;
          isInteractive = true;
        } else {
          status = 'Check In';
          icon = Icons.pending_rounded;
          color = AppTheme.errorColor;
          isInteractive = true;
        }

        return GestureDetector(
          onTap: isInteractive
              ? () {
            if (!isCheckedIn) {
              firebaseService.recordCheckIn(widget.userId);
            } else if (!isCheckedOut) {
              firebaseService.recordCheckOut(attendance.id);
            }
          }
              : null,
          child: _buildStatusCard(status, '', icon, color, isInteractive),
        );
      },
    );
  }

  Widget _buildRecurringTasksSection() {
    return StreamBuilder<List<RecurringTask>>(
      stream: _taskSchedulingService.getStaffRecurringTasks(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox.shrink();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final recurringTasks = snapshot.data!
            .where((task) => task.status == RecurringTaskStatus.active)
            .toList();

        if (recurringTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.repeat_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Recurring Tasks',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${recurringTasks.length} Active',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...recurringTasks.take(3).map((task) => _buildRecurringTaskItem(task)),
                if (recurringTasks.length > 3) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      // TODO: Navigate to full recurring tasks list
                    },
                    child: const Text('View all recurring tasks'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecurringTaskItem(RecurringTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _getFrequencyColor(task.frequency).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getFrequencyIcon(task.frequency),
              color: _getFrequencyColor(task.frequency),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      task.frequency.name,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (task.preferredTime != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'at ${task.preferredTime!.format(context)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (task.preferredDays.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDays(task.preferredDays),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${task.currentOccurrences}',
              style: const TextStyle(
                color: AppTheme.successColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getFrequencyColor(CleaningFrequency frequency) {
    switch (frequency) {
      case CleaningFrequency.daily:
        return AppTheme.primaryColor;
      case CleaningFrequency.weekly:
        return AppTheme.accentColor;
      case CleaningFrequency.monthly:
        return AppTheme.secondaryColor;
      case CleaningFrequency.quarterly:
        return AppTheme.warningColor;
      case CleaningFrequency.annually:
        return Colors.purple;
    }
  }

  IconData _getFrequencyIcon(CleaningFrequency frequency) {
    switch (frequency) {
      case CleaningFrequency.daily:
        return Icons.today;
      case CleaningFrequency.weekly:
        return Icons.calendar_view_week;
      case CleaningFrequency.monthly:
        return Icons.calendar_month;
      case CleaningFrequency.quarterly:
        return Icons.date_range;
      case CleaningFrequency.annually:
        return Icons.event;
    }
  }

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((day) => dayNames[day - 1]).join(', ');
  }

  Widget _buildStatusCard(String title, String subtitle, IconData icon, Color color, bool isInteractive) {
    return Card(
      elevation: 0,
      color: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (isInteractive) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.touch_app_rounded,
                      color: color,
                      size: 16,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentNotifications(BuildContext context, FirebaseService firebaseService) {
    return StreamBuilder<List<AppNotification>>(
      stream: firebaseService.getNotificationsForUser(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final notifications = snapshot.data ?? [];
        if (notifications.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_off, color: Colors.grey[400]),
                const SizedBox(width: 12),
                Text(
                  'No new notifications',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        final recentNotifications = notifications.take(3).toList();
        return Column(
          children: recentNotifications.map((notification) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: notification.read ? 1 : 3,
              color: notification.read ? Colors.grey[50] : Colors.white,
              child: ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: notification.read ? Colors.grey[300] : AppTheme.primaryColor,
                  radius: 16,
                  child: Icon(
                    Icons.notifications,
                    color: notification.read ? Colors.grey[600] : Colors.white,
                    size: 16,
                  ),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.read ? FontWeight.normal : FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                subtitle: Text(
                  '${notification.message}\nYou • ${_formatTimestamp(notification.timestamp)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: notification.read ? Colors.grey[600] : Colors.black87,
                    fontSize: 12,
                  ),
                ),
                trailing: !notification.read
                    ? IconButton(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  onPressed: () {
                    firebaseService.markNotificationAsRead(notification.id);
                  },
                )
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildPriorityTasks(BuildContext context, List<CleaningTask> allTasks) {
    final overdueTasks = allTasks.where((task) => task.status != CleaningStatus.completed && task.dueDate.isBefore(DateTime.now())).toList();

    final urgentTasks = allTasks
        .where((task) =>
    task.status != CleaningStatus.completed &&
        task.dueDate.isAfter(DateTime.now()) &&
        task.dueDate.isBefore(DateTime.now().add(const Duration(hours: 24))))
        .toList();

    if (overdueTasks.isEmpty && urgentTasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200] ?? Colors.green),        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'All tasks are on schedule!',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (overdueTasks.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200] ?? Colors.red),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have ${overdueTasks.length} overdue task${overdueTasks.length == 1 ? '' : 's'} that need${overdueTasks.length == 1 ? 's' : ''} immediate attention.',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          ...overdueTasks.take(2).map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskCard(
              task: task,
              userRole: UserRole.staff,
              userId: widget.userId,
              onDismissed: () {},
            ),
          )),
        ],
        if (urgentTasks.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[200] ?? Colors.orange),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange[600], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You have ${urgentTasks.length} urgent task${urgentTasks.length == 1 ? '' : 's'} due within 24 hours.',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          ...urgentTasks.take(2).map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskCard(
              task: task,
              userRole: UserRole.staff,
              userId: widget.userId,
              onDismissed: () {},
            ),
          )),
        ],
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}

Widget buildAnimatedMetricCard(BuildContext context, String title, String value, IconData icon, Color color) {
  return Card(
    elevation: 0,
    color: AppTheme.surfaceColor,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class TaskStatusPieChart extends StatelessWidget {
  final List<CleaningTask> tasks;

  const TaskStatusPieChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('No tasks to display.'),
      );
    }
    final pending = tasks.where((task) => task.status == CleaningStatus.pending).length;
    final inProgress = tasks.where((task) => task.status == CleaningStatus.inProgress).length;
    final completed = tasks.where((task) => task.status == CleaningStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Task Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: MediaQuery.of(context).size.width < 400 ? 150 : 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: MediaQuery.of(context).size.width < 400 ? 40 : 60,
                sections: [
                  if (pending > 0)
                    PieChartSectionData(
                      value: pending.toDouble(),
                      title: pending > 0 ? '$pending' : '',
                      color: AppTheme.warningColor,
                      radius: MediaQuery.of(context).size.width < 400 ? 30 : 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (inProgress > 0)
                    PieChartSectionData(
                      value: inProgress.toDouble(),
                      title: inProgress > 0 ? '$inProgress' : '',
                      color: AppTheme.accentColor,
                      radius: MediaQuery.of(context).size.width < 400 ? 30 : 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  if (completed > 0)
                    PieChartSectionData(
                      value: completed.toDouble(),
                      title: completed > 0 ? '$completed' : '',
                      color: AppTheme.successColor,
                      radius: MediaQuery.of(context).size.width < 400 ? 30 : 40,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (pending > 0) _buildLegendItem('Pending', AppTheme.warningColor, pending),
              if (inProgress > 0) _buildLegendItem('In Progress', AppTheme.accentColor, inProgress),
              if (completed > 0) _buildLegendItem('Completed', AppTheme.successColor, completed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ($count)',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

class TasksPerAreaBarChart extends StatelessWidget {
  final List<CleaningTask> tasks;

  const TasksPerAreaBarChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text('No tasks to display.'),
      );
    }
    final tasksPerArea = <CleaningArea, int>{};
    for (final area in CleaningArea.values) {
      tasksPerArea[area] = tasks.where((task) => task.area == area).length;
    }

    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    final chartHeight = isSmallScreen ? 200.0 : 250.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Text(
            'Tasks per Area',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: chartHeight,
              width: CleaningArea.values.length * (isSmallScreen ? 30.0 : 40.0),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: tasksPerArea.values.isEmpty ? 10.0 : (tasksPerArea.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
                  barGroups: tasksPerArea.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key.index,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: AppTheme.primaryColor,
                          width: isSmallScreen ? 8 : 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isSmallScreen ? 40 : 60,
                        getTitlesWidget: (value, meta) {
                          String areaName = CleaningArea.values[value.toInt()].toString().split('.').last;
                          final Map<String, String> shortNames = {
                            'lectureHalls': 'LH',
                            'computerLabs': 'CL',
                            'washrooms': 'WR',
                            'libraryStudyAreas': 'LSA',
                            'cafeteria': 'C',
                            'corridorsStairsElevators': 'CSE',
                            'outdoorAreas': 'OA',
                            'storerooms': 'SR',
                            'labs': 'Labs',
                            'carpets': 'Car',
                            'externalWalls': 'EW',
                          };
                          areaName = shortNames[areaName] ?? areaName.substring(0, 1);
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              areaName,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 8 : 9,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          );
                        },
                        interval: 1,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: isSmallScreen ? 25 : 30,
                        getTitlesWidget: (value, meta) => Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 8 : 9,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

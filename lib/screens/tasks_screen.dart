// ignore_for_file: use_build_context_synchronously

import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/models/user_role.dart';
import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/models/recurring_task.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/task_scheduling_service.dart';
import 'package:staff_cleaning/screens/task_detail_screen.dart';
import 'package:staff_cleaning/widgets/add_task_dialog.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class TasksScreen extends StatefulWidget {
  final UserRole userRole;
  final String? userId;

  const TasksScreen({super.key, required this.userRole, this.userId});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum TimePeriod { daily, weekly, monthly, annually }
enum SortOption { dueDate, status, area, title, createdAt }

class TaskStatusPieChart extends StatelessWidget {
  final List<CleaningTask> tasks;

  const TaskStatusPieChart({super.key, required this.tasks});

  @override
  Widget build(BuildContext context) {
    final pending = tasks.where((task) => task.status == CleaningStatus.pending).length;
    final inProgress = tasks.where((task) => task.status == CleaningStatus.inProgress).length;
    final completed = tasks.where((task) => task.status == CleaningStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.all(4.0),
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
            height: MediaQuery.of(context).size.width < 400 ? 120 : 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: MediaQuery.of(context).size.width < 400 ? 30 : 50,
                sections: [
                  PieChartSectionData(
                    value: pending.toDouble(),
                    title: pending > 0 ? '$pending' : '',
                    color: AppTheme.warningColor,
                    radius: MediaQuery.of(context).size.width < 400 ? 25 : 35,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: inProgress.toDouble(),
                    title: inProgress > 0 ? '$inProgress' : '',
                    color: AppTheme.accentColor,
                    radius: MediaQuery.of(context).size.width < 400 ? 25 : 35,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: completed.toDouble(),
                    title: completed > 0 ? '$completed' : '',
                    color: AppTheme.successColor,
                    radius: MediaQuery.of(context).size.width < 400 ? 25 : 35,
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

class _TasksScreenState extends State<TasksScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TaskSchedulingService _taskSchedulingService = TaskSchedulingService();
  CleaningStatus? _selectedStatusFilter;
  CleaningArea? _selectedAreaFilter;
  TimePeriod? _selectedTimePeriod;
  String? _selectedStaffFilter;
  bool _showRecurringTasks = false;
  final SortOption _sortOption = SortOption.dueDate;
  final bool _sortAscending = true;



  IconData _getTimePeriodIcon(TimePeriod period) {
    switch (period) {
      case TimePeriod.daily:
        return Icons.today;
      case TimePeriod.weekly:
        return Icons.calendar_view_week;
      case TimePeriod.monthly:
        return Icons.calendar_month;
      case TimePeriod.annually:
        return Icons.calendar_today;
    }
  }




  List<CleaningTask> _filterTasksByPeriod(List<CleaningTask> tasks, TimePeriod? period) {
    if (period == null) return tasks;
    
    final now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case TimePeriod.daily:
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case TimePeriod.weekly:
        // Get Monday of current week (weekday: 1=Monday, 7=Sunday)
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.userRole == UserRole.admin ? 'All Tasks' : 'My Tasks'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          if (widget.userRole == UserRole.admin) ...[
            // Toggle between regular and recurring tasks
            IconButton(
              icon: Icon(_showRecurringTasks ? Icons.task_alt : Icons.repeat),
              tooltip: _showRecurringTasks ? 'Show Regular Tasks' : 'Show Recurring Tasks',
              onPressed: () {
                setState(() {
                  _showRecurringTasks = !_showRecurringTasks;
                });
              },
            ),
          ],
          PopupMenuButton<TimePeriod?>(
            icon: const Icon(Icons.date_range_rounded),
            tooltip: 'Filter by Time Period',
            onSelected: (period) {
              setState(() {
                _selectedTimePeriod = period;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(Icons.all_inclusive, size: 20),
                    SizedBox(width: 8),
                    Text('All Time'),
                  ],
                ),
              ),
              ...TimePeriod.values.map((period) => PopupMenuItem(
                value: period,
                child: Row(
                  children: [
                    Icon(_getTimePeriodIcon(period), size: 20),
                    SizedBox(width: 8),
                    Text(period.name.toUpperCase()),
                  ],
                ),
              )),
            ],
          ),
        ],
),
      body: Column(
        children: [
          // Filters section for admin
          if (widget.userRole == UserRole.admin) _buildFiltersSection(),
          
          // Tasks content
          Expanded(
            child: _showRecurringTasks 
                ? _buildRecurringTasksList()
                : _buildRegularTasksList(),
          ),
        ],
      ),
      floatingActionButton: widget.userRole == UserRole.admin
          ? FloatingActionButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AddTaskDialog(),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filters',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Status and Area filters
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<CleaningStatus?>(
                  isExpanded: true,
                  initialValue: _selectedStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Status')),
                    ...CleaningStatus.values.map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.name.toUpperCase()),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<CleaningArea?>(
                isExpanded: true,
                initialValue: _selectedAreaFilter,
                decoration: const InputDecoration(
                    labelText: 'Area',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Areas')),
                    ...CleaningArea.values.map((area) => DropdownMenuItem(
                      value: area,
                      child: Text(
                        _shortAreaName(area),
                        overflow: TextOverflow.ellipsis,
                      ),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedAreaFilter = value;
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Staff member filter
          StreamBuilder<List<AppUserData>>(
            stream: _firebaseService.getStaffMembers(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 48);
              }
              
              final staff = snapshot.data!;
              return DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _selectedStaffFilter,
                decoration: const InputDecoration(
                  labelText: 'Staff Member',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Staff')),
                  ...staff.map((user) => DropdownMenuItem(
                    value: user.uid,
                    child: Text(user.name ?? user.email),
                  )),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStaffFilter = value;
                  });
                },
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          // Clear filters button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedStatusFilter = null;
                    _selectedAreaFilter = null;
                    _selectedStaffFilter = null;
                    _selectedTimePeriod = null;
                  });
                },
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Clear All Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRegularTasksList() {
    return StreamBuilder<List<CleaningTask>>(
      stream: widget.userRole == UserRole.admin
          ? _firebaseService.getTasks()
          : _firebaseService.getStaffTasks(widget.userId!),
      builder: (context, snapshot) {
if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading tasks...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          if (snapshot.hasError) {
            final BuildContext currentContext = context;
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(currentContext);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!currentContext.mounted) {
                return;
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text('Error loading tasks: ${snapshot.error}'),
                  backgroundColor: Colors.red,
                ),
              );
            });
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to load tasks', style: TextStyle(color: Colors.red)),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          List<CleaningTask> tasks = snapshot.data ?? [];

          // Apply admin filters
          if (widget.userRole == UserRole.admin) {
            // Apply staff filter
            if (_selectedStaffFilter != null) {
              tasks = tasks.where((task) => task.assignedTo == _selectedStaffFilter).toList();
            }
            
            // Apply status filter
            if (_selectedStatusFilter != null) {
              tasks = tasks.where((task) => task.status == _selectedStatusFilter).toList();
            }
            
            // Apply area filter
            if (_selectedAreaFilter != null) {
              tasks = tasks.where((task) => task.area == _selectedAreaFilter).toList();
            }
          }

          // Apply time period filter
          tasks = _filterTasksByPeriod(tasks, _selectedTimePeriod);

          // Apply sorting
          tasks.sort((a, b) {
            int comparison = 0;
            switch (_sortOption) {
              case SortOption.dueDate:
                comparison = a.dueDate.compareTo(b.dueDate);
                break;
              case SortOption.status:
                comparison = a.status.name.compareTo(b.status.name);
                break;
              case SortOption.area:
                comparison = a.area.name.compareTo(b.area.name);
                break;
              case SortOption.title:
                comparison = a.title.compareTo(b.title);
                break;
              case SortOption.createdAt:
                // Use dueDate as proxy for createdAt if not available
                comparison = a.dueDate.compareTo(b.dueDate);
                break;
            }
            return _sortAscending ? comparison : -comparison;
          });

          if (tasks.isEmpty) {
            // Show filtered empty state
            String message = 'No tasks found';
            if (widget.userRole == UserRole.admin && 
                (_selectedTimePeriod != null || _selectedStatusFilter != null || 
                 _selectedAreaFilter != null || _selectedStaffFilter != null)) {
              message += ' matching your filters';
            } else if (widget.userRole == UserRole.staff && 
                       (_selectedTimePeriod != null || _selectedStatusFilter != null || 
                        _selectedAreaFilter != null)) {
              message += ' matching your filters';
            }
            message += '.';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
                  if ((widget.userRole == UserRole.admin && 
                       (_selectedTimePeriod != null || _selectedStatusFilter != null || 
                        _selectedAreaFilter != null || _selectedStaffFilter != null)) ||
                      (widget.userRole == UserRole.staff && 
                       (_selectedTimePeriod != null || _selectedStatusFilter != null || 
                        _selectedAreaFilter != null))) ...[
                    SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedTimePeriod = null;
                          _selectedStatusFilter = null;
                          _selectedAreaFilter = null;
                          _selectedStaffFilter = null;
                        });
                      },
                      icon: Icon(Icons.clear),
                      label: Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            );
          }

           if (widget.userRole == UserRole.staff && MediaQuery.of(context).size.width >= 400) {
             return Column(
               children: [
                 Padding(
                   padding: const EdgeInsets.all(4.0),
                   child: TaskStatusPieChart(tasks: tasks),
                 ),
                 Expanded(
                   child: ListView.builder(
                     itemCount: tasks.length,
                     itemBuilder: (context, index) {
                       final task = tasks[index];
                       return TaskCard(
                         task: task,
                         userRole: widget.userRole,
                         userId: widget.userId,
                         onDismissed: () {
                           _firebaseService.deleteTask(task.id);
                         },
                       );
                     },
                   ),
                 ),
               ],
             );
           } else {
              return ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return TaskCard(
                    task: task,
                    userRole: widget.userRole,
                    userId: widget.userId,
                    onDismissed: () {
                      _firebaseService.deleteTask(task.id);
                    },
                  );
                },
              );
            }
        }
    );
  }

  Widget _buildRecurringTasksList() {
    return StreamBuilder<List<RecurringTask>>(
      stream: _taskSchedulingService.getAllRecurringTasks(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading recurring tasks...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Failed to load recurring tasks', style: TextStyle(color: Colors.red)),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        List<RecurringTask> recurringTasks = snapshot.data ?? [];

        // Apply admin filters
        if (_selectedStaffFilter != null) {
          recurringTasks = recurringTasks.where((task) => task.assignedTo == _selectedStaffFilter).toList();
        }
        
        if (_selectedStatusFilter != null) {
          final statusMap = {
            CleaningStatus.pending: RecurringTaskStatus.active,
            CleaningStatus.inProgress: RecurringTaskStatus.active,
            CleaningStatus.completed: RecurringTaskStatus.active,
          };
          final targetStatus = statusMap[_selectedStatusFilter];
          if (targetStatus != null) {
            recurringTasks = recurringTasks.where((task) => task.status == targetStatus).toList();
          }
        }
        
        if (_selectedAreaFilter != null) {
          recurringTasks = recurringTasks.where((task) => task.area == _selectedAreaFilter).toList();
        }

        // Apply time period filter based on next due date
        if (_selectedTimePeriod != null) {
          final now = DateTime.now();
          final filteredTasks = <RecurringTask>[];
          
          for (final task in recurringTasks) {
            final nextDueDate = task.getNextDueDate(now);
            if (nextDueDate != null) {
              final startDate = _getPeriodStartDate(_selectedTimePeriod!);
              if (nextDueDate.isAfter(startDate) || nextDueDate.isAtSameMomentAs(startDate)) {
                filteredTasks.add(task);
              }
            }
          }
          recurringTasks = filteredTasks;
        }

        // Sort by creation date (newest first)
        recurringTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (recurringTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.repeat, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No recurring tasks found',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (_selectedTimePeriod != null || _selectedStatusFilter != null || 
                    _selectedAreaFilter != null || _selectedStaffFilter != null) ...[
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedTimePeriod = null;
                        _selectedStatusFilter = null;
                        _selectedAreaFilter = null;
                        _selectedStaffFilter = null;
                      });
                    },
                    icon: Icon(Icons.clear),
                    label: Text('Clear Filters'),
                  ),
                ],
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: recurringTasks.length,
          itemBuilder: (context, index) {
            final recurringTask = recurringTasks[index];
            return RecurringTaskCard(
              recurringTask: recurringTask,
              userRole: widget.userRole,
              onEdit: () => _editRecurringTask(recurringTask),
              onDelete: () => _deleteRecurringTask(recurringTask),
              onPause: () => _pauseRecurringTask(recurringTask),
              onResume: () => _resumeRecurringTask(recurringTask),
              onGenerateNow: () => _generateTaskNow(recurringTask),
            );
          },
        );
      },
    );
  }

  DateTime _getPeriodStartDate(TimePeriod period) {
    final now = DateTime.now();
    switch (period) {
      case TimePeriod.daily:
        return DateTime(now.year, now.month, now.day);
      case TimePeriod.weekly:
        final daysFromMonday = (now.weekday - 1) % 7;
        return now.subtract(Duration(days: daysFromMonday));
      case TimePeriod.monthly:
        return DateTime(now.year, now.month, 1);
      case TimePeriod.annually:
        return DateTime(now.year, 1, 1);
    }
  }

  String _shortAreaName(CleaningArea area) {
    switch (area) {
      case CleaningArea.lectureHalls:
        return 'Lecture Halls';
      case CleaningArea.computerLabs:
        return 'Computer Labs';
      case CleaningArea.washrooms:
        return 'Washrooms';
      case CleaningArea.libraryStudyAreas:
        return 'Library';
      case CleaningArea.cafeteria:
        return 'Cafeteria';
      case CleaningArea.corridorsStairsElevators:
        return 'Corridors';
      case CleaningArea.outdoorAreas:
        return 'Outdoor';
      case CleaningArea.storerooms:
        return 'Storerooms';
      case CleaningArea.labs:
        return 'Labs';
      case CleaningArea.carpets:
        return 'Carpets';
      case CleaningArea.externalWalls:
        return 'Ext Walls';
    }
  }

  Future<void> _editRecurringTask(RecurringTask task) async {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit functionality coming soon')),
    );
  }

  Future<void> _deleteRecurringTask(RecurringTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Task'),
        content: Text('Are you sure you want to delete "${task.title}"? This will stop all future automatic generations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskSchedulingService.deleteRecurringTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring task deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: $e')),
        );
      }
    }
  }

  Future<void> _pauseRecurringTask(RecurringTask task) async {
    try {
      await _taskSchedulingService.pauseRecurringTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task paused')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pausing task: $e')),
      );
    }
  }

  Future<void> _resumeRecurringTask(RecurringTask task) async {
    try {
      await _taskSchedulingService.resumeRecurringTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task resumed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resuming task: $e')),
      );
    }
  }

  Future<void> _generateTaskNow(RecurringTask task) async {
    try {
      await _taskSchedulingService.manuallyGenerateTask(task.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task generated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating task: $e')),
      );
    }
  }




} 


class TaskCard extends StatelessWidget {
  final CleaningTask task;
  final UserRole userRole;
  final String? userId;
  final VoidCallback onDismissed;

  const TaskCard({
    super.key,
    required this.task,
    required this.userRole,
    this.userId,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(task.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      direction: userRole == UserRole.admin ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (direction) {
        onDismissed();
      },
      child: Card(
        elevation: 0,
        color: AppTheme.surfaceColor,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: Column( // Added Column here
          children: [
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isThreeLine: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(
                      task: task,
                      userRole: userRole,
                      userId: userId,
                    ),
                  ),
                );
              },
              leading: CircleAvatar(
                backgroundColor: _getAreaColor(task.area).withAlpha(25),
                child: Icon(_getAreaIcon(task.area), color: _getAreaColor(task.area)),
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Text(
                '${task.description}\nAssigned to: ${task.assignedToName}',
                style: TextStyle(color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                softWrap: true,
              ),
              trailing: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 110),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(task.status).withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      task.status.toString().split('.').last,
                      style: TextStyle(
                        color: _getStatusColor(task.status),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (userRole == UserRole.admin)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => ReassignTaskDialog(task: task),
                        );
                      },
                      child: const Text('Re-assign'),
                    ),
                  ],
                ),
              ),
            if (userRole == UserRole.staff)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap( // Changed from Row to Wrap
                  spacing: 8.0, // horizontal space between buttons
                  runSpacing: 4.0, // vertical space between lines of buttons
                  alignment: WrapAlignment.center,
                  children: CleaningStatus.values.map((status) {
                    return ElevatedButton(
                      onPressed: () {
                        FirebaseService().updateTask(task.id, {'status': status.name});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: task.status == status ? AppTheme.primaryColor : Colors.grey.shade300,
                        foregroundColor: task.status == status ? Colors.white : AppTheme.textSecondary,
                        minimumSize: Size.zero, // Remove fixed size constraints
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Custom padding
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap, // Shrink tap area
                      ),
                      child: Text(
                        status.toString().split('.').last,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getAreaColor(CleaningArea area) {
    switch (area) {
      case CleaningArea.lectureHalls:
        return AppTheme.primaryColor;
      case CleaningArea.computerLabs:
        return AppTheme.accentColor;
      case CleaningArea.washrooms:
        return AppTheme.secondaryColor;
      case CleaningArea.libraryStudyAreas:
        return AppTheme.warningColor;
      case CleaningArea.cafeteria:
        return AppTheme.successColor;
      case CleaningArea.corridorsStairsElevators:
        return AppTheme.accentColor;
      case CleaningArea.outdoorAreas:
        return AppTheme.successColor;
      case CleaningArea.storerooms:
      case CleaningArea.labs:
      case CleaningArea.carpets:
      case CleaningArea.externalWalls:
        return AppTheme.textSecondary;
    }
  }

  Color _getStatusColor(CleaningStatus status) {
    switch (status) {
      case CleaningStatus.pending:
        return AppTheme.warningColor;
      case CleaningStatus.inProgress:
        return AppTheme.accentColor;
      case CleaningStatus.completed:
        return AppTheme.successColor;
    }
  }

  IconData _getAreaIcon(CleaningArea area) {
    switch (area) {
      case CleaningArea.lectureHalls:
        return Icons.meeting_room;
      case CleaningArea.computerLabs:
        return Icons.computer;
      case CleaningArea.washrooms:
        return Icons.wc;
      case CleaningArea.libraryStudyAreas:
        return Icons.library_books;
      case CleaningArea.cafeteria:
        return Icons.restaurant;
      case CleaningArea.corridorsStairsElevators:
        return Icons.stairs;
      case CleaningArea.outdoorAreas:
        return Icons.park;
      default:
        return Icons.cleaning_services;
    }
  }
}

class RecurringTaskCard extends StatelessWidget {
  final RecurringTask recurringTask;
  final UserRole userRole;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onGenerateNow;

  const RecurringTaskCard({
    super.key,
    required this.recurringTask,
    required this.userRole,
    required this.onEdit,
    required this.onDelete,
    required this.onPause,
    required this.onResume,
    required this.onGenerateNow,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nextDueDate = recurringTask.getNextDueDate(now);
    
    return Card(
      elevation: 0,
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getFrequencyColor(recurringTask.frequency).withAlpha(25),
                  child: Icon(_getFrequencyIcon(recurringTask.frequency), color: _getFrequencyColor(recurringTask.frequency)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recurringTask.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Assigned to: ${recurringTask.assignedToName}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(recurringTask.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recurringTask.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(recurringTask.status),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              recurringTask.description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 12),
            
            // Details
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildDetailChip(Icons.repeat, recurringTask.frequency.name),
                _buildDetailChip(Icons.schedule, _formatTime(recurringTask.preferredTime)),
                if (recurringTask.preferredDays.isNotEmpty)
                  _buildDetailChip(Icons.calendar_today, _formatDays(recurringTask.preferredDays)),
                _buildDetailChip(Icons.bar_chart, '${recurringTask.currentOccurrences} generated'),
                if (recurringTask.maxOccurrences != null)
                  _buildDetailChip(Icons.flag, 'Max: ${recurringTask.maxOccurrences}'),
                if (nextDueDate != null)
                  _buildDetailChip(Icons.event, 'Next: ${_formatDate(nextDueDate)}'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (userRole == UserRole.admin) ...[
                  if (recurringTask.status == RecurringTaskStatus.active) ...[
                    IconButton(
                      onPressed: onPause,
                      icon: const Icon(Icons.pause),
                      tooltip: 'Pause',
                    ),
                    IconButton(
                      onPressed: onGenerateNow,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Generate Now',
                    ),
                  ] else if (recurringTask.status == RecurringTaskStatus.paused) ...[
                    IconButton(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow),
                      tooltip: 'Resume',
                    ),
                  ],
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RecurringTaskStatus status) {
    switch (status) {
      case RecurringTaskStatus.active:
        return AppTheme.successColor;
      case RecurringTaskStatus.paused:
        return AppTheme.warningColor;
      case RecurringTaskStatus.cancelled:
        return Colors.red;
    }
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

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Any time';
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDays(List<int> days) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((day) => dayNames[day - 1]).join(', ');
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class ReassignTaskDialog extends StatefulWidget {
  final CleaningTask task;

  const ReassignTaskDialog({super.key, required this.task});

  @override
  State<ReassignTaskDialog> createState() => _ReassignTaskDialogState();
}

class _ReassignTaskDialogState extends State<ReassignTaskDialog> {
  final FirebaseService _firebaseService = FirebaseService();
  String? _selectedStaffId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Re-assign Task'),
      content: StreamBuilder<List<AppUserData>>(
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
            initialValue: _selectedStaffId,
            hint: const Text('Select a staff member'),
            onChanged: (value) {
              setState(() {
                _selectedStaffId = value;
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
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (_selectedStaffId != null) {
                await _firebaseService.updateTask(widget.task.id, {
                  'assignedTo': _selectedStaffId,
                  'assignedToName': (await _firebaseService.getUserData(_selectedStaffId!))?.name ?? '',
                });
                if (mounted) {
                  Navigator.of(context).pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Task re-assigned successfully!')),
                  );
                }
              }
            },
          child: const Text('Re-assign'),
        ),
      ],
    );
  }
}

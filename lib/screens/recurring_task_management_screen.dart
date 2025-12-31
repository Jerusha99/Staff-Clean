import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/recurring_task.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/services/task_scheduling_service.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:staff_cleaning/widgets/add_task_dialog.dart';

class RecurringTaskManagementScreen extends StatefulWidget {
  const RecurringTaskManagementScreen({super.key});

  @override
  State<RecurringTaskManagementScreen> createState() => _RecurringTaskManagementScreenState();
}

class _RecurringTaskManagementScreenState extends State<RecurringTaskManagementScreen> {
  final TaskSchedulingService _taskSchedulingService = TaskSchedulingService();
  RecurringTaskStatus? _selectedStatusFilter;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Map<String, dynamic> _statistics = {};

  Future<void> _loadStatistics() async {
    try {
      final stats = await _taskSchedulingService.getRecurringTaskStatistics();
      if (mounted) {
        setState(() {
          _statistics = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading statistics: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Tasks'),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {});
              _loadStatistics();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Statistics Cards
          _buildStatisticsCards(),
          
          // Search and Filters
          _buildSearchAndFilters(),
          
          // Tasks List
          Expanded(
            child: StreamBuilder<List<RecurringTask>>(
              stream: _taskSchedulingService.getAllRecurringTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                List<RecurringTask> tasks = snapshot.data ?? [];

                // Apply filters
                if (_selectedStatusFilter != null) {
                  tasks = tasks.where((task) => task.status == _selectedStatusFilter).toList();
                }

                if (_searchQuery.isNotEmpty) {
                  tasks = tasks.where((task) =>
                    task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    task.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    task.assignedToName.toLowerCase().contains(_searchQuery.toLowerCase())
                  ).toList();
                }

                if (tasks.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.repeat, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No recurring tasks found',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const AddTaskDialog(),
                            );
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create Recurring Task'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return RecurringTaskCard(
                      task: task,
                      onEdit: () => _editTask(task),
                      onDelete: () => _deleteTask(task),
                      onPause: () => _pauseTask(task),
                      onResume: () => _resumeTask(task),
                      onCancel: () => _cancelTask(task),
                      onGenerateNow: () => _generateTaskNow(task),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const AddTaskDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatisticsCards() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              title: 'Total',
              value: _statistics['totalTasks']?.toString() ?? '0',
              icon: Icons.repeat,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: 'Active',
              value: _statistics['activeTasks']?.toString() ?? '0',
              icon: Icons.play_arrow,
              color: AppTheme.successColor,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _StatCard(
              title: 'Generated',
              value: _statistics['totalGenerated']?.toString() ?? '0',
              icon: Icons.check_circle,
              color: AppTheme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Search bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Search recurring tasks...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              isDense: true,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 8),
          
          // Status filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedStatusFilter == null,
                  onSelected: (selected) {
                    setState(() {
                      _selectedStatusFilter = selected ? null : _selectedStatusFilter;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ...RecurringTaskStatus.values.map((status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status.name.toUpperCase()),
                    selected: _selectedStatusFilter == status,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatusFilter = selected ? status : null;
                      });
                    },
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editTask(RecurringTask task) async {
    await showDialog(
      context: context,
      builder: (context) => AddTaskDialog(task: task),
    );
  }

  Future<void> _deleteTask(RecurringTask task) async {
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recurring task deleted successfully')),
        );
        _loadStatistics();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: $e')),
        );
      }
    }
  }

  Future<void> _pauseTask(RecurringTask task) async {
    try {
      await _taskSchedulingService.pauseRecurringTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task paused')),
      );
      _loadStatistics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error pausing task: $e')),
      );
    }
  }

  Future<void> _resumeTask(RecurringTask task) async {
    try {
      await _taskSchedulingService.resumeRecurringTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task resumed')),
      );
      _loadStatistics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resuming task: $e')),
      );
    }
  }

  Future<void> _cancelTask(RecurringTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Recurring Task'),
        content: Text('Are you sure you want to cancel "${task.title}"? This will stop all future automatic generations.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cancel Task'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskSchedulingService.cancelRecurringTask(task.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task cancelled')),
        );
        _loadStatistics();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling task: $e')),
        );
      }
    }
  }

  Future<void> _generateTaskNow(RecurringTask task) async {
    try {
      await _taskSchedulingService.manuallyGenerateTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task generated successfully')),
      );
      _loadStatistics();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating task: $e')),
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class RecurringTaskCard extends StatelessWidget {
  final RecurringTask task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onGenerateNow;

  const RecurringTaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onGenerateNow,
  });

  @override
  Widget build(BuildContext context) {
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
                  backgroundColor: _getFrequencyColor(task.frequency).withValues(alpha: 0.1),
                  child: Icon(_getFrequencyIcon(task.frequency), color: _getFrequencyColor(task.frequency)),
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
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Assigned to: ${task.assignedToName}',
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
                    color: _getStatusColor(task.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.status.name.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(task.status),
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
              task.description,
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
              spacing: 12,
              runSpacing: 4,
              children: [
                _buildDetailChip(Icons.repeat, task.frequency.name),
                _buildDetailChip(Icons.schedule, _formatTime(task.preferredTime)),
                if (task.preferredDays.isNotEmpty)
                  _buildDetailChip(Icons.calendar_today, _formatDays(task.preferredDays)),
                _buildDetailChip(Icons.bar_chart, '${task.currentOccurrences} generated'),
                if (task.maxOccurrences != null)
                  _buildDetailChip(Icons.flag, 'Max: ${task.maxOccurrences}'),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (task.status == RecurringTaskStatus.active) ...[
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
                ] else if (task.status == RecurringTaskStatus.paused) ...[
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
                  onPressed: onCancel,
                  icon: const Icon(Icons.cancel),
                  tooltip: 'Cancel',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete),
                  tooltip: 'Delete',
                ),
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
}
import 'package:staff_cleaning/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:staff_cleaning/models/cleaning_task.dart';
import 'package:staff_cleaning/models/recurring_task.dart';
import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/task_scheduling_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth

class AddTaskDialog extends StatefulWidget {
  final RecurringTask? task;
  const AddTaskDialog({super.key, this.task});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final FirebaseService _firebaseService = FirebaseService();
  final TaskSchedulingService _taskSchedulingService = TaskSchedulingService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuth _auth = FirebaseAuth.instance; // Initialize FirebaseAuth
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  CleaningArea? _selectedArea;
  String? _selectedStaffId;
  DateTime? _selectedDate;
  CleaningFrequency? _selectedFrequency;
  TimeOfDay? _selectedTime;
  bool _isRecurringTask = false;
  // ignore: prefer_final_fields
  List<int> _selectedWeekDays = [];
  DateTime? _recurringStartDate;
  DateTime? _recurringEndDate;
  int? _maxOccurrences;

  String? _currentCreatorUid;
  String? _currentCreatorName;

@override
  void initState() {
    super.initState();
    _loadCreatorInfo();
    if (widget.task != null) {
      _isRecurringTask = true;
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _selectedArea = widget.task!.area;
      _selectedStaffId = widget.task!.assignedTo;
      _selectedFrequency = widget.task!.frequency;
      _selectedTime = widget.task!.preferredTime;
      _selectedWeekDays = widget.task!.preferredDays;
      _recurringStartDate = widget.task!.startDate;
      _recurringEndDate = widget.task!.endDate;
      _maxOccurrences = widget.task!.maxOccurrences;
    } else {
      _recurringStartDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
  }

  Future<void> _loadCreatorInfo() async {
    final user = _auth.currentUser;
    if (user != null) {
      _currentCreatorUid = user.uid;
      final userData = await _firebaseService.getUserData(user.uid);
      _currentCreatorName = userData?.name ?? userData?.email ?? 'Unknown';
    }
  }

@override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 600;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 8 : 16,
        vertical: isSmallScreen ? 8 : 24,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * (isSmallScreen ? 0.95 : 0.85),
          maxWidth: screenSize.width * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBar(
                title: Text(widget.task == null
                    ? (_isRecurringTask ? 'Add Recurring Task' : 'Add New Task')
                    : 'Edit Recurring Task'),
                automaticallyImplyLeading: false,
                toolbarHeight: isSmallScreen ? 48 : 56,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Task type toggle
                      SwitchListTile(
                        title: const Text('Recurring Task'),
                        subtitle: const Text('Enable automatic task generation'),
                        value: _isRecurringTask,
                        onChanged: (value) {
                          setState(() {
                            _isRecurringTask = value;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (value) => value!.isEmpty ? 'Please enter a title' : null,
                      ),
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 2,
                        validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
                      ),
                      const SizedBox(height: 8),
                      
                      DropdownButtonFormField<CleaningArea>(
                        initialValue: _selectedArea,
                        hint: const Text('Select Area'),
                        items: CleaningArea.values.map((area) {
                          return DropdownMenuItem(
                            value: area,
                            child: Text(area.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedArea = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select an area' : null,
                      ),
                      const SizedBox(height: 8),
                      
                      StreamBuilder<List<AppUserData>>(
                        stream: _firebaseService.getStaffMembers(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 48,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final staff = snapshot.data!;
                          return DropdownButtonFormField<String>(
                            initialValue: _selectedStaffId,
                            hint: const Text('Assign to Staff'),
                            items: staff.map((user) {
                              return DropdownMenuItem(
                                value: user.uid,
                                child: Text(
                                  user.email,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStaffId = value;
                              });
                            },
                            validator: (value) => value == null ? 'Please assign to a staff member' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      
                      DropdownButtonFormField<CleaningFrequency>(
                        initialValue: _selectedFrequency,
                        hint: const Text('Select Frequency'),
                        items: CleaningFrequency.values.map((frequency) {
                          return DropdownMenuItem(
                            value: frequency,
                            child: Text(frequency.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFrequency = value;
                          });
                        },
                        validator: (value) => value == null ? 'Please select a frequency' : null,
                      ),
                      const SizedBox(height: 8),
                      
                      // Time selection
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Preferred Time: ${_selectedTime?.format(context) ?? 'Not selected'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        trailing: const Icon(Icons.access_time, size: 20),
                        onTap: () async {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime ?? TimeOfDay.now(),
                          );
                          if (pickedTime != null) {
                            setState(() {
                              _selectedTime = pickedTime;
                            });
                          }
                        },
                      ),
                      
                      if (!_isRecurringTask) ...[
                        // Single task due date
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _selectedDate == null
                                ? 'Select Due Date'
                                : 'Due Date: ${_selectedDate!.toLocal()}'.split(' ')[0],
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _selectedDate = pickedDate;
                              });
                            }
                          },
                        ),
                      ] else ...[
                        // Recurring task options
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Start Date: ${_recurringStartDate?.toLocal()}'.split(' ')[0],
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _recurringStartDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _recurringStartDate = pickedDate;
                              });
                            }
                          },
                        ),
                        
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _recurringEndDate == null
                                ? 'End Date (Optional)'
                                : 'End Date: ${_recurringEndDate!.toLocal()}'.split(' ')[0],
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_recurringEndDate != null)
                                IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _recurringEndDate = null;
                                    });
                                  },
                                ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: _recurringEndDate ?? DateTime.now(),
                              firstDate: _recurringStartDate ?? DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (pickedDate != null) {
                              setState(() {
                                _recurringEndDate = pickedDate;
                              });
                            }
                          },
                        ),
                        
                        // Week days selection for weekly frequency
                        if (_selectedFrequency == CleaningFrequency.weekly) ...[
                          const Text(
                            'Select Days:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
                            ].asMap().entries.map((entry) {
                              final dayIndex = entry.key + 1; // 1-7 (Monday-Sunday)
                              final dayName = entry.value;
                              final isSelected = _selectedWeekDays.contains(dayIndex);
                              
                              return FilterChip(
                                label: Text(dayName, style: const TextStyle(fontSize: 12)),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedWeekDays.add(dayIndex);
                                    } else {
                                      _selectedWeekDays.remove(dayIndex);
                                    }
                                  });
                                },
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Max occurrences
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Max Occurrences (Optional)',
                            hintText: 'Leave empty for unlimited',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              _maxOccurrences = value.isNotEmpty ? int.tryParse(value) : null;
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        await _saveTask();
                      },
                      child: Text(widget.task == null
                          ? (_isRecurringTask ? 'Create Recurring Task' : 'Add Task')
                          : 'Update Task'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveTask() async {
    final navigator = Navigator.of(context);
    
    if (!_formKey.currentState!.validate() ||
        _selectedArea == null ||
        _selectedStaffId == null ||
        _selectedFrequency == null ||
        _currentCreatorUid == null ||
        _currentCreatorName == null) {
      return;
    }

    if (!_isRecurringTask && _selectedDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a due date')),
      );
      return;
    }

    if (_isRecurringTask && _recurringStartDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start date')),
      );
      return;
    }

    if (_isRecurringTask && _selectedFrequency == CleaningFrequency.weekly && _selectedWeekDays.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one day for weekly tasks')),
      );
      return;
    }

    final assignedToUserData = await _firebaseService.getUserData(_selectedStaffId!);
    final assignedToName = assignedToUserData?.name ?? assignedToUserData?.email ?? 'Unknown';

    if (widget.task != null) {
      // Update existing recurring task
      final updatedTask = widget.task!.copyWith(
        title: _titleController.text,
        description: _descriptionController.text,
        area: _selectedArea,
        assignedTo: _selectedStaffId,
        assignedToName: assignedToName,
        frequency: _selectedFrequency,
        preferredTime: _selectedTime,
        preferredDays: _selectedWeekDays,
        startDate: _recurringStartDate,
        endDate: _recurringEndDate,
        maxOccurrences: _maxOccurrences,
      );

      await _taskSchedulingService.updateRecurringTask(widget.task!.id, updatedTask.toMap());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring task updated successfully!')),
      );
    } else if (_isRecurringTask) {
      // Create new recurring task
      final recurringTask = RecurringTask(
        id: '', // ID will be generated by Firebase
        title: _titleController.text,
        description: _descriptionController.text,
        area: _selectedArea!,
        assignedTo: _selectedStaffId!,
        assignedToName: assignedToName,
        frequency: _selectedFrequency!,
        preferredTime: _selectedTime,
        preferredDays: _selectedWeekDays,
        startDate: _recurringStartDate!,
        endDate: _recurringEndDate,
        maxOccurrences: _maxOccurrences,
        creatorUid: _currentCreatorUid!,
        creatorName: _currentCreatorName!,
        createdAt: DateTime.now(),
      );
      
      await _taskSchedulingService.addRecurringTask(recurringTask);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recurring task created successfully!')),
      );
    } else {
      // Create single task
      final task = CleaningTask(
        id: '', // ID will be generated by Firebase
        title: _titleController.text,
        description: _descriptionController.text,
        area: _selectedArea!,
        assignedTo: _selectedStaffId!,
        assignedToName: assignedToName,
        dueDate: _selectedDate!,
        frequency: _selectedFrequency!,
        creatorUid: _currentCreatorUid!,
        creatorName: _currentCreatorName!,
      );
      
      await _firebaseService.addTask(task);
      
      _notificationService.showNotification(
        'New Task Assigned',
        'You have been assigned a new task: ${task.title}',
      );
      
      _notificationService.scheduleNotification(
        task.hashCode,
        'Task Due: ${task.title}',
        'The task "${task.title}" is due today.',
        task.dueDate,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully!')),
      );
    }

    if (!mounted) return;
    navigator.pop();
  }
}

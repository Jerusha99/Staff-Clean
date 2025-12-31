import 'package:flutter/material.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/security_service.dart';
import 'package:staff_cleaning/services/validation_service.dart';
import 'package:staff_cleaning/services/error_handling_service.dart';
import 'package:staff_cleaning/models/shift.dart';
import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/utils/theme.dart';

import 'package:staff_cleaning/widgets/bubble_animations.dart';
import 'package:staff_cleaning/screens/view_shifts_screen.dart';


class ShiftManagementScreen extends StatefulWidget {
  const ShiftManagementScreen({super.key});

  @override
  State<ShiftManagementScreen> createState() => _ShiftManagementScreenState();
}

class _ShiftManagementScreenState extends State<ShiftManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  TimeOfDay? _breakStartTime;
  TimeOfDay? _breakEndTime;
  String? _selectedStaffId;
  List<AppUserData> _staffMembers = [];

  bool _isLoading = false;
  bool _isRecurring = false;
  String _recurringType = 'weekly'; // daily, weekly, monthly

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
      final staffStream = _firebaseService.getStaffMembers();
      staffStream.listen((staff) {
        if (mounted) {
          setState(() {
            _staffMembers = staff;
            _isLoading = false;
          });

          // Show toast if no staff members found
          if (staff.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No staff members found. Add staff members first to create shifts.'),
                    duration: Duration(seconds: 4),
                  ),
                );
              }
            });
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandlingService.showErrorSnackBar(context, 'Error loading data: $e');
      }
    }
  }

  Future<void> _createShift() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final startDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );
      
      final endDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      // Validate shift time
      final validationError = ValidationService.validateShiftTime(startDateTime, endDateTime);
      if (validationError != null) {
        if (!mounted) return;
        ErrorHandlingService.showErrorSnackBar(context, validationError);
        setState(() => _isLoading = false);
        return;
      }

      final selectedStaff = _staffMembers.firstWhere((staff) => staff.uid == _selectedStaffId);
      
      final shift = Shift(
        id: '', // Will be set by Firebase
        userId: _selectedStaffId!,
        userName: selectedStaff.name ?? 'Unknown Staff',
        startTime: startDateTime,
        endTime: endDateTime,
        breakStartTime: _breakStartTime != null ? DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _breakStartTime!.hour,
          _breakStartTime!.minute,
        ) : null,
        breakEndTime: _breakEndTime != null ? DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _breakEndTime!.hour,
          _breakEndTime!.minute,
        ) : null,
      );

      await _firebaseService.addShift(shift);
      
      if (_isRecurring) {
        await _createRecurringShifts(shift);
      }
      
      _clearForm();
      if (!mounted) return;
      ErrorHandlingService.showSuccessSnackBar(context, 'Shift created successfully!');
      
    } catch (e) {
      if (!mounted) return;
      ErrorHandlingService.showErrorSnackBar(context, 'Error creating shift: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createRecurringShifts(Shift baseShift) async {
    for (int i = 1; i <= 4; i++) { // Create 4 weeks of shifts
      final shiftDate = _startDate.add(Duration(days: i * 7));
      final recurringShift = Shift(
        id: '',
        userId: baseShift.userId,
        userName: baseShift.userName,
        startTime: DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
          baseShift.startTime.hour,
          baseShift.startTime.minute,
        ),
        endTime: DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
          baseShift.endTime.hour,
          baseShift.endTime.minute,
        ),
        breakStartTime: baseShift.breakStartTime != null ? DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
          baseShift.breakStartTime!.hour,
          baseShift.breakStartTime!.minute,
        ) : null,
        breakEndTime: baseShift.breakEndTime != null ? DateTime(
          shiftDate.year,
          shiftDate.month,
          shiftDate.day,
          baseShift.breakEndTime!.hour,
          baseShift.breakEndTime!.minute,
        ) : null,
      );
      
      await _firebaseService.addShift(recurringShift);
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedStaffId = null;
      _breakStartTime = null;
      _breakEndTime = null;
      _isRecurring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BubbleBackground(
      colors: [
        AppTheme.secondaryColor.withValues(alpha: 0.1),
        AppTheme.accentColor.withValues(alpha: 0.05),
        AppTheme.primaryColor.withValues(alpha: 0.08),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Create Shift'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: _isLoading
            ? ErrorHandlingService.createLoadingWidget(message: 'Loading shift data...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with View Shifts Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Shift Management',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        BubbleButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ViewShiftsScreen(),
                              ),
                            );
                          },
                          backgroundColor: AppTheme.primaryColor,
                          child: const Text('View All Shifts'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Staff Members Overview
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Staff Members Overview',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _staffMembers.isEmpty
                              ? Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No staff members available',
                                        style: TextStyle(color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Add staff members in Staff Management to create shifts',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _staffMembers.length,
                                  itemBuilder: (context, index) {
                                    final staff = _staffMembers[index];
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                                            child: Text(
                                              (staff.name ?? '').isNotEmpty ? (staff.name ?? '')[0].toUpperCase() : 'U',
                                              style: TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  staff.name ?? 'Unknown Staff',
                                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  staff.email,
                                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    color: AppTheme.textSecondary,
                                                  ),
                                                ),
                                                if (staff.phone != null && staff.phone!.isNotEmpty)
                                                  Text(
                                                    'Phone: ${staff.phone}',
                                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                      color: AppTheme.textSecondary,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Create Shift Form
                    BubbleCard(
                      isAnimating: true,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Create New Shift',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Staff Selection
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
                              validator: (value) => ValidationService.validateRequired(value, 'Staff member'),
                              onChanged: (value) {
                                setState(() => _selectedStaffId = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Date Selection
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (date != null) {
                                        setState(() => _startDate = date);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'End Date',
                                      prefixIcon: Icon(Icons.calendar_today),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate,
                                        firstDate: _startDate,
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (date != null) {
                                        setState(() => _endDate = date);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Time Selection
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Start Time',
                                      prefixIcon: Icon(Icons.access_time),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: _startTime.format(context),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _startTime,
                                      );
                                      if (time != null) {
                                        setState(() => _startTime = time);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'End Time',
                                      prefixIcon: Icon(Icons.access_time),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: _endTime.format(context),
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _endTime,
                                      );
                                      if (time != null) {
                                        setState(() => _endTime = time);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            // Break Times
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Break Start (Optional)',
                                      prefixIcon: Icon(Icons.free_breakfast),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: _breakStartTime?.format(context) ?? '',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _breakStartTime ?? TimeOfDay.now(),
                                      );
                                      if (time != null) {
                                        setState(() => _breakStartTime = time);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    decoration: const InputDecoration(
                                      labelText: 'Break End (Optional)',
                                      prefixIcon: Icon(Icons.free_breakfast),
                                      border: OutlineInputBorder(),
                                    ),
                                    controller: TextEditingController(
                                      text: _breakEndTime?.format(context) ?? '',
                                    ),
                                    readOnly: true,
                                    onTap: () async {
                                      final time = await showTimePicker(
                                        context: context,
                                        initialTime: _breakEndTime ?? TimeOfDay.now(),
                                      );
                                      if (time != null) {
                                        setState(() => _breakEndTime = time);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            // Recurring Options
                            CheckboxListTile(
                              title: const Text('Recurring Shift'),
                              subtitle: const Text('Create this shift for multiple weeks'),
                              value: _isRecurring,
                              onChanged: (value) {
                                setState(() => _isRecurring = value ?? false);
                              },
                            ),
                            
                            if (_isRecurring) ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                initialValue: _recurringType,
                                decoration: const InputDecoration(
                                  labelText: 'Recurring Type',
                                  prefixIcon: Icon(Icons.repeat),
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                                  DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                                ],
                                onChanged: (value) {
                                  setState(() => _recurringType = value!);
                                },
                              ),
                            ],
                            
                            const SizedBox(height: 24),
                            
                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              child: BubbleButton(
                                onPressed: _isLoading ? null : _createShift,
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Text('Create Shift'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Shift Statistics
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shift Statistics',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildShiftStats(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildShiftStats() {
    return StreamBuilder<List<Shift>>(
      stream: _firebaseService.getAllShifts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No shifts scheduled yet.');
        }
        
        final shifts = snapshot.data!;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final todayShifts = shifts.where((shift) {
          final shiftDate = DateTime(
            shift.startTime.year,
            shift.startTime.month,
            shift.startTime.day,
          );
          return shiftDate.isAtSameMomentAs(today);
        }).length;
        
        final thisWeekShifts = shifts.where((shift) {
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 7));
          return (shift.startTime.isAtSameMomentAs(weekStart) || shift.startTime.isAfter(weekStart)) && shift.startTime.isBefore(weekEnd);
        }).length;
        
        final totalHours = shifts.fold<double>(0, (sum, shift) {
          return sum + shift.endTime.difference(shift.startTime).inHours;
        });
        
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Today\'s Shifts', todayShifts.toString(), Icons.today, AppTheme.accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('This Week', thisWeekShifts.toString(), Icons.date_range, AppTheme.successColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total Shifts', shifts.length.toString(), Icons.schedule, AppTheme.warningColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard('Total Hours', totalHours.toStringAsFixed(1), Icons.access_time, AppTheme.secondaryColor),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

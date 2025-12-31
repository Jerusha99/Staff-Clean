import 'package:flutter/material.dart';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/services/security_service.dart';
import 'package:staff_cleaning/services/error_handling_service.dart';
import 'package:staff_cleaning/models/attendance.dart';
import 'package:staff_cleaning/models/user_data.dart';
import 'package:staff_cleaning/widgets/bubble_animations.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AttendanceTrackingScreen extends StatefulWidget {
  const AttendanceTrackingScreen({super.key});

  @override
  State<AttendanceTrackingScreen> createState() => _AttendanceTrackingScreenState();
}

class _AttendanceTrackingScreenState extends State<AttendanceTrackingScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Attendance> _attendanceRecords = [];
  List<Attendance> _weeklyAttendanceRecords = [];
  List<AppUserData> _staffMembers = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final securityService = SecurityService();
    if (!await securityService.isAdmin()) {
      if (mounted) {
        ErrorHandlingService.showErrorSnackBar(context, 'Access denied. Admin privileges required.');
      }
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

      // Load weekly attendance records
      final weeklyAttendanceStream = _firebaseService.getWeeklyAttendance();
      weeklyAttendanceStream.listen((weeklyAttendance) {
        if (mounted) {
          setState(() => _weeklyAttendanceRecords = weeklyAttendance);
        }
      });
      
      // Load attendance records
      await _loadAttendanceData();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ErrorHandlingService.showErrorSnackBar(context, 'Error loading data: $e');
      }
    }
  }

  Future<void> _loadAttendanceData() async {
    // This would need to be implemented in FirebaseService
    // For now, we'll use the existing daily attendance
    final allAttendance = <Attendance>[];
    
    for (final staff in _staffMembers) {
      final attendanceStream = _firebaseService.getDailyAttendance(staff.uid, _selectedDate);
      final attendance = await attendanceStream.firstWhere(
        (att) => att != null,
        orElse: () => null,
      );
      if (attendance != null) {
        allAttendance.add(attendance);
      }
    }
    
    setState(() {
      _attendanceRecords = allAttendance;
      _isLoading = false;
    });

    // Show toast if no attendance records found
    if (allAttendance.isEmpty && _staffMembers.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No attendance records found for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}. Staff members may not have checked in yet.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      });
    }
  }

  Map<String, dynamic> _calculateAttendanceStats() {
    final totalStaff = _staffMembers.length;
    final presentStaff = _attendanceRecords.length;
    final absentStaff = totalStaff - presentStaff;
    final lateStaff = _attendanceRecords.where((a) {
      // Consider late if check-in is after 9:00 AM
      final checkInHour = a.checkInTime.hour;
      return checkInHour > 9;
    }).length;
    
    // Calculate total hours worked
    double totalHours = 0;
    for (final attendance in _attendanceRecords) {
      if (attendance.checkOutTime != null) {
        totalHours += attendance.checkOutTime!.difference(attendance.checkInTime).inHours;
      }
    }
    
    return {
      'totalStaff': totalStaff,
      'presentStaff': presentStaff,
      'absentStaff': absentStaff,
      'lateStaff': lateStaff,
      'attendanceRate': totalStaff > 0 ? (presentStaff / totalStaff * 100).round() : 0,
      'totalHours': totalHours,
      'averageHours': presentStaff > 0 ? totalHours / presentStaff : 0,
    };
  }

  List<BarChartGroupData> _getWeeklyChartData() {
    final data = <BarChartGroupData>[];
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    for (int i = 0; i < weekDays.length; i++) {
      final day = weekDays[i];
      final presentStaff = _weeklyAttendanceRecords
          .where((att) => DateFormat('E').format(att.date) == day && att.checkInTime != null)
          .length;
      final absentStaff = _staffMembers.length - presentStaff;

      data.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: presentStaff.toDouble(),
              color: AppTheme.successColor,
              width: 12,
            ),
            BarChartRodData(
              toY: absentStaff.toDouble(),
              color: AppTheme.errorColor,
              width: 12,
            ),
          ],
        ),
      );
    }
    
    return data;
  }

  List<PieChartSectionData> _getAttendancePieData() {
    final stats = _calculateAttendanceStats();
    
    return [
      PieChartSectionData(
        value: stats['presentStaff'].toDouble(),
        title: 'Present',
        color: AppTheme.successColor,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: stats['absentStaff'].toDouble(),
        title: 'Absent',
        color: AppTheme.errorColor,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      PieChartSectionData(
        value: stats['lateStaff'].toDouble(),
        title: 'Late',
        color: AppTheme.warningColor,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return BubbleBackground(
      colors: [
        AppTheme.warningColor.withValues(alpha: 0.08),
        AppTheme.successColor.withValues(alpha: 0.05),
        AppTheme.accentColor.withValues(alpha: 0.06),
      ],
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Attendance Tracking'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: _isLoading
            ? ErrorHandlingService.createLoadingWidget(message: 'Loading attendance data...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Date',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Date',
                                    prefixIcon: Icon(Icons.calendar_today),
                                    border: OutlineInputBorder(),
                                  ),
                                  controller: TextEditingController(
                                    text: DateFormat('MMM dd, yyyy').format(_selectedDate),
                                  ),
                                  readOnly: true,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _selectedDate = date;
                                      });
                                      await _loadAttendanceData();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              BubbleButton(
                                onPressed: () async {
                                  setState(() => _selectedDate = DateTime.now());
                                  await _loadAttendanceData();
                                },
                                child: const Text('Today'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Statistics Overview
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Attendance Overview',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildStatsGrid(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Charts Section
                    Row(
                      children: [
                        Expanded(
                          child: BubbleCard(
                            isAnimating: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Attendance Distribution',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: PieChart(
                                    PieChartData(
                                      sections: _getAttendancePieData(),
                                      centerSpaceRadius: 40,
                                      sectionsSpace: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: BubbleCard(
                            isAnimating: true,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly Trend',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 200,
                                  child: BarChart(
                                    BarChartData(
                                      alignment: BarChartAlignment.spaceAround,
                                      barGroups: _getWeeklyChartData(),
                                      titlesData: FlTitlesData(
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            getTitlesWidget: (value, meta) {
                                              final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                child: Text(days[value.toInt()]),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(showTitles: false),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      gridData: const FlGridData(show: false),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Detailed Attendance List
                    BubbleCard(
                      isAnimating: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  'Detailed Attendance',
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              BubbleButton(
                                onPressed: _markAttendance,
                                child: const Text('Mark Attendance'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildAttendanceList(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _markAttendance() async {
    final selectedStaff = await _showStaffSelectionDialog();
    if (selectedStaff != null) {
      final attendance = _attendanceRecords.firstWhere(
        (att) => att.userId == selectedStaff.uid,
        orElse: () => Attendance(
          id: '',
          userId: selectedStaff.uid,
          checkInTime: DateTime.now(),
          date: _selectedDate,
        ),
      );

      if (attendance.id.isEmpty) {
        // Not checked in yet
        final selectedTime = await _selectTime(context, TimeOfDay.now());
        if (selectedTime != null) {
          final selectedDateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          await _firebaseService.recordCheckIn(selectedStaff.uid, checkInTime: selectedDateTime);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checked in ${selectedStaff.name}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else if (attendance.checkOutTime == null) {
        // Checked in, but not checked out
        final selectedTime = await _selectTime(context, TimeOfDay.now());
        if (selectedTime != null) {
          final selectedDateTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
          await _firebaseService.recordCheckOut(attendance.id, checkOutTime: selectedDateTime);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Checked out ${selectedStaff.name}'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        // Already checked out
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedStaff.name} has already checked out for today.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
      }
      await _loadAttendanceData();
    }
  }

  Future<TimeOfDay?> _selectTime(BuildContext context, TimeOfDay initialTime) async {
    return await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }

  Future<AppUserData?> _showStaffSelectionDialog() async {
    return showDialog<AppUserData>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Staff Member'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _staffMembers.length,
              itemBuilder: (context, index) {
                final staff = _staffMembers[index];
                return ListTile(
                  title: Text(staff.name ?? 'Unknown'),
                  onTap: () {
                    Navigator.of(context).pop(staff);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    final stats = _calculateAttendanceStats();
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Staff',
                stats['totalStaff'].toString(),
                Icons.people,
                AppTheme.accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Present',
                stats['presentStaff'].toString(),
                Icons.check_circle,
                AppTheme.successColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Absent',
                stats['absentStaff'].toString(),
                Icons.cancel,
                AppTheme.errorColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Late',
                stats['lateStaff'].toString(),
                Icons.schedule,
                AppTheme.warningColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Attendance Rate',
                '${stats['attendanceRate']}%',
                Icons.percent,
                AppTheme.secondaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Avg Hours',
                stats['averageHours'].toStringAsFixed(1),
                Icons.access_time,
                AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ],
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
            child: Icon(icon, color: color, size: 20),
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
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    if (_staffMembers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No staff members found',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _staffMembers.map((staff) {
        final attendance = _attendanceRecords.firstWhere(
          (att) => att.userId == staff.uid,
          orElse: () => Attendance(
            id: '',
            userId: staff.uid,
            checkInTime: DateTime.now(),
            date: _selectedDate,
          ),
        );
        
        String workingHours = '';
        if (attendance.id.isNotEmpty && attendance.checkOutTime != null) {
          final difference = attendance.checkOutTime!.difference(attendance.checkInTime);
          workingHours = '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
        }

        return Card(
          color: AppTheme.surfaceColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                staff.name != null && staff.name!.isNotEmpty ? staff.name![0].toUpperCase() : '?',
                style: TextStyle(color: AppTheme.primaryColor),
              ),
            ),
            title: Text(
              staff.name ?? 'Unknown Staff',
              style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (attendance.id.isNotEmpty)
                  Text(
                    'Check-in: ${DateFormat('hh:mm a').format(attendance.checkInTime)}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                else
                  Text(
                    'Not checked in',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                if (attendance.checkOutTime != null)
                  Text(
                    'Check-out: ${DateFormat('hh:mm a').format(attendance.checkOutTime!)}',
                    style: TextStyle(color: AppTheme.textSecondary),
                  )
                else if (attendance.id.isNotEmpty)
                  Text('Not checked out', style: TextStyle(color: AppTheme.warningColor)),
                if (workingHours.isNotEmpty)
                  Text(
                    'Working Hours: $workingHours',
                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
            trailing: attendance.id.isEmpty
                ? Icon(Icons.close, color: AppTheme.errorColor)
                : attendance.checkOutTime != null
                    ? Icon(Icons.check_circle, color: AppTheme.successColor)
                    : Icon(Icons.pending, color: AppTheme.warningColor),
          ),
        );
      }).toList(),
    );
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/models/shift.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:staff_cleaning/widgets/bubble_animations.dart';
import 'package:staff_cleaning/services/error_handling_service.dart';

class ViewShiftsScreen extends StatefulWidget {
  const ViewShiftsScreen({super.key});

  @override
  State<ViewShiftsScreen> createState() => _ViewShiftsScreenState();
}

class _ViewShiftsScreenState extends State<ViewShiftsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Shift> _shifts = [];
  bool _isLoading = true;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Set a timeout for loading
    _loadingTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        debugPrint('Loading timeout reached');
        setState(() => _isLoading = false);
        // Just stop loading without showing error message
      }
    });
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      debugPrint('Starting to load shifts...');

      // Test Firebase connectivity (silently)
      try {
        // Skip connectivity test for now to avoid private member access
        debugPrint('Skipping Firebase connectivity test');
      } catch (e) {
        debugPrint('Firebase connectivity test failed: $e');
        // Continue anyway, don't throw error
      }

      // Load shifts
      debugPrint('Loading shifts from Firebase...');
      final shiftsStream = _firebaseService.getAllShifts();

      // Add timeout to the stream
      final timeoutStream = shiftsStream.timeout(
        const Duration(seconds: 15), // Increased timeout
        onTimeout: (sink) {
          debugPrint('Shifts stream timed out after 15 seconds');
          // Just complete the stream without error
          sink.close();
        },
      );

      timeoutStream.listen(
        (shifts) {
          debugPrint('Successfully received ${shifts.length} shifts from Firebase');
          _loadingTimer?.cancel();
          if (mounted) {
            setState(() {
              _shifts = shifts;
              _isLoading = false;
            });

            // Show toast if no shifts found
            if (shifts.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('No shifts have been scheduled yet. Create your first shift in Shift Management.'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              });
            }
          }
        },
        onError: (error) {
          debugPrint('Error in shifts stream: $error');
          _loadingTimer?.cancel();
          if (mounted) {
            setState(() => _isLoading = false);
            // Show empty state instead of error message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to load shifts. Showing empty list.'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            });
          }
        },
        onDone: () {
          _loadingTimer?.cancel();
          debugPrint('Shifts stream completed successfully');
        },
      );
    } catch (e, stackTrace) {
      debugPrint('Exception in _loadData: $e');
      debugPrint('Stack trace: $stackTrace');
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
        // Just show empty state without error message
      }
    }
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
          title: const Text('All Shifts'),
          backgroundColor: AppTheme.surfaceColor,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Shifts',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _shifts = [];
                });
                _loadData();
              },
            ),

          ],
        ),
        body: _isLoading
            ? ErrorHandlingService.createLoadingWidget(message: 'Loading shifts...')
            : _shifts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No shifts have been created yet',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Create shifts in the Shift Management section',
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) {
                      final shift = _shifts[index];
                      return BubbleCard(
                        isAnimating: true,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header
                              Text(
                                'Shift #${shift.id.substring(0, 8)}',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Staff Member
                              Row(
                                children: [
                                  const Icon(Icons.person, size: 20, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Staff: ${shift.userName}',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Date and Time
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 20, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Date: ${shift.startTime.day}/${shift.startTime.month}/${shift.startTime.year}',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, size: 20, color: AppTheme.primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Time: ${shift.startTime.hour}:${shift.startTime.minute.toString().padLeft(2, '0')} - ${shift.endTime.hour}:${shift.endTime.minute.toString().padLeft(2, '0')}',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),

                              // Break times if available
                              if (shift.breakStartTime != null && shift.breakEndTime != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.free_breakfast, size: 20, color: AppTheme.secondaryColor),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Break: ${shift.breakStartTime!.hour}:${shift.breakStartTime!.minute.toString().padLeft(2, '0')} - ${shift.breakEndTime!.hour}:${shift.breakEndTime!.minute.toString().padLeft(2, '0')}',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],


                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
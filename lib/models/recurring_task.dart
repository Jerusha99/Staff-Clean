import 'package:flutter/material.dart';
import 'cleaning_task.dart';

enum RecurringTaskStatus { active, paused, cancelled }

class RecurringTask {
  final String id;
  final String title;
  final String description;
  final CleaningArea area;
  final String assignedTo;
  final String assignedToName;
  final CleaningFrequency frequency;
  final TimeOfDay? preferredTime;
  final List<int> preferredDays; // Days of week (1-7, Monday-Sunday)
  final DateTime startDate;
  final DateTime? endDate;
  final RecurringTaskStatus status;
  final String creatorUid;
  final String creatorName;
  final DateTime createdAt;
  final DateTime? lastGeneratedDate;
  final int? maxOccurrences; // Optional limit on how many times to generate
  final int currentOccurrences; // Track how many tasks have been generated

  RecurringTask({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.assignedTo,
    required this.assignedToName,
    required this.frequency,
    this.preferredTime,
    this.preferredDays = const [],
    required this.startDate,
    this.endDate,
    this.status = RecurringTaskStatus.active,
    required this.creatorUid,
    required this.creatorName,
    required this.createdAt,
    this.lastGeneratedDate,
    this.maxOccurrences,
    this.currentOccurrences = 0,
  });

  factory RecurringTask.fromMap(String id, Map<dynamic, dynamic> data) {
    return RecurringTask(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      area: CleaningArea.values.firstWhere(
          (e) => e.toString() == 'CleaningArea.${data['area'] as String? ?? 'storerooms'}',
          orElse: () => CleaningArea.storerooms),
      assignedTo: data['assignedTo'] ?? '',
      assignedToName: data['assignedToName'] ?? '',
      frequency: CleaningFrequency.values.firstWhere(
          (e) => e.toString() == 'CleaningFrequency.${data['frequency'] as String? ?? 'weekly'}',
          orElse: () => CleaningFrequency.weekly),
      preferredTime: data['preferredTime'] != null 
          ? TimeOfDay(
              hour: data['preferredTime']['hour'] ?? 9,
              minute: data['preferredTime']['minute'] ?? 0,
            )
          : null,
      preferredDays: List<int>.from(data['preferredDays'] ?? []),
      startDate: DateTime.fromMillisecondsSinceEpoch(data['startDate'] as int),
      endDate: data['endDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['endDate'] as int)
          : null,
      status: RecurringTaskStatus.values.firstWhere(
          (e) => e.toString() == 'RecurringTaskStatus.${data['status'] as String? ?? 'active'}',
          orElse: () => RecurringTaskStatus.active),
      creatorUid: data['creatorUid'] ?? '',
      creatorName: data['creatorName'] ?? 'Unknown',
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['createdAt'] as int),
      lastGeneratedDate: data['lastGeneratedDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(data['lastGeneratedDate'] as int)
          : null,
      maxOccurrences: data['maxOccurrences'],
      currentOccurrences: data['currentOccurrences'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'area': area.toString().split('.').last,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'frequency': frequency.toString().split('.').last,
      'preferredTime': preferredTime != null ? {
        'hour': preferredTime!.hour,
        'minute': preferredTime!.minute,
      } : null,
      'preferredDays': preferredDays,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate?.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'creatorUid': creatorUid,
      'creatorName': creatorName,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'lastGeneratedDate': lastGeneratedDate?.millisecondsSinceEpoch,
      'maxOccurrences': maxOccurrences,
      'currentOccurrences': currentOccurrences,
    };
  }

  // Check if this recurring task should generate a new task today
  bool shouldGenerateTask(DateTime currentDate) {
    if (status != RecurringTaskStatus.active) {
      return false;
    }
    
    // Check if we've reached max occurrences
        if (maxOccurrences != null && currentOccurrences >= maxOccurrences!) {
      return false;
    }
    
    // Check if we've passed the end date
        if (endDate != null && currentDate.isAfter(endDate!)) {
      return false;
    }
    
    // Check if we've already generated a task for this frequency period
    if (lastGeneratedDate != null) {
      switch (frequency) {
        case CleaningFrequency.daily:
                    if (currentDate.difference(lastGeneratedDate!).inDays < 1) {
            return false;
          }
          break;
        case CleaningFrequency.weekly:
                    if (currentDate.difference(lastGeneratedDate!).inDays < 7) {
            return false;
          }
          break;
        case CleaningFrequency.monthly:
                    if (currentDate.year == lastGeneratedDate!.year && 
              currentDate.month == lastGeneratedDate!.month) {
            return false;
          }
          break;
        case CleaningFrequency.quarterly:
                    final monthsDiff = (currentDate.year - lastGeneratedDate!.year) * 12 + 
                           (currentDate.month - lastGeneratedDate!.month);
          if (monthsDiff < 3) {
            return false;
          }
          break;
        case CleaningFrequency.annually:
                    if (currentDate.year == lastGeneratedDate!.year) {
            return false;
          }
          break;
      }
    }
    
    // Check if current date matches preferred days (for weekly frequency)
        if (frequency == CleaningFrequency.weekly && preferredDays.isNotEmpty) {
      final currentDay = currentDate.weekday; // 1=Monday, 7=Sunday
      if (!preferredDays.contains(currentDay)) {
        return false;
      }
    }
    
    // Check if we've passed the start date
        if (currentDate.isBefore(startDate)) {
      return false;
    }
    
    return true;
  }

  // Get the next due date for task generation
  DateTime? getNextDueDate(DateTime currentDate) {
        if (status != RecurringTaskStatus.active) {
      return null;
    }
    if (maxOccurrences != null && currentOccurrences >= maxOccurrences!) {
      return null;
    }
    if (endDate != null && currentDate.isAfter(endDate!)) {
      return null;
    }
    
    DateTime nextDate = currentDate;
    
    switch (frequency) {
      case CleaningFrequency.daily:
        if (lastGeneratedDate != null) {
          nextDate = lastGeneratedDate!.add(const Duration(days: 1));
        }
        break;
      case CleaningFrequency.weekly:
        if (preferredDays.isNotEmpty) {
          // Find next preferred day
          for (int i = 0; i < 7; i++) {
            final checkDate = currentDate.add(Duration(days: i));
            final dayOfWeek = checkDate.weekday;
            if (preferredDays.contains(dayOfWeek)) {
              nextDate = checkDate;
              break;
            }
          }
        } else {
          if (lastGeneratedDate != null) {
            nextDate = lastGeneratedDate!.add(const Duration(days: 7));
          }
        }
        break;
      case CleaningFrequency.monthly:
        if (lastGeneratedDate != null) {
          nextDate = DateTime(lastGeneratedDate!.year, lastGeneratedDate!.month + 1, startDate.day);
        } else {
          nextDate = DateTime(currentDate.year, currentDate.month, startDate.day);
        }
        break;
      case CleaningFrequency.quarterly:
        if (lastGeneratedDate != null) {
          nextDate = DateTime(lastGeneratedDate!.year, lastGeneratedDate!.month + 3, startDate.day);
        } else {
          nextDate = DateTime(currentDate.year, currentDate.month, startDate.day);
        }
        break;
      case CleaningFrequency.annually:
        if (lastGeneratedDate != null) {
          nextDate = DateTime(lastGeneratedDate!.year + 1, startDate.month, startDate.day);
        } else {
          nextDate = DateTime(currentDate.year, startDate.month, startDate.day);
        }
        break;
    }
    
    // Apply preferred time
        if (preferredTime != null) {
      nextDate = DateTime(
        nextDate.year,
        nextDate.month,
        nextDate.day,
        preferredTime!.hour,
        preferredTime!.minute,
      );
    }
    
    return nextDate;
  }

  // Create a CleaningTask from this recurring task
  CleaningTask generateCleaningTask() {
    final now = DateTime.now();
    DateTime dueDate = now;
    
    // Apply preferred time
        if (preferredTime != null) {
      dueDate = DateTime(
        now.year,
        now.month,
        now.day,
        preferredTime!.hour,
        preferredTime!.minute,
      );
    }
    
    return CleaningTask(
      id: '', // Will be generated by Firebase
      title: title,
      description: description,
      area: area,
      assignedTo: assignedTo,
      assignedToName: assignedToName,
      dueDate: dueDate,
      frequency: frequency,
      creatorUid: creatorUid,
      creatorName: creatorName,
    );
  }

  RecurringTask copyWith({
    String? id,
    String? title,
    String? description,
    CleaningArea? area,
    String? assignedTo,
    String? assignedToName,
    CleaningFrequency? frequency,
    TimeOfDay? preferredTime,
    List<int>? preferredDays,
    DateTime? startDate,
    DateTime? endDate,
    RecurringTaskStatus? status,
    String? creatorUid,
    String? creatorName,
    DateTime? createdAt,
    DateTime? lastGeneratedDate,
    int? maxOccurrences,
    int? currentOccurrences,
  }) {
    return RecurringTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      area: area ?? this.area,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      frequency: frequency ?? this.frequency,
      preferredTime: preferredTime ?? this.preferredTime,
      preferredDays: preferredDays ?? this.preferredDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      creatorUid: creatorUid ?? this.creatorUid,
      creatorName: creatorName ?? this.creatorName,
      createdAt: createdAt ?? this.createdAt,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
      maxOccurrences: maxOccurrences ?? this.maxOccurrences,
      currentOccurrences: currentOccurrences ?? this.currentOccurrences,
    );
  }
}
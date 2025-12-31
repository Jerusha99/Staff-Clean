import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';


import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cleaning_task.dart';
import '../models/app_notification.dart';
import '../models/issue.dart';


class OfflineService {
  static const String _offlineTasksKey = 'offline_tasks';
  static const String _offlineNotificationsKey = 'offline_notifications';
  static const String _offlineIssuesKey = 'offline_issues';
  static const String _syncQueueKey = 'sync_queue';
  static const String _lastSyncKey = 'last_sync';
  
  static bool _isOnline = true;
  static StreamController<bool>? _connectivityController;
  static Timer? _syncTimer;

  /// Initialize offline service
  static Future<void> initialize() async {
    _connectivityController = StreamController<bool>.broadcast();
    
    // Start periodic sync when online
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      if (_isOnline) {
        syncData();
      }
    });
    
    // Check initial connectivity
    await checkConnectivity();
  }

  /// Check current connectivity status
  static Future<bool> checkConnectivity() async {
    try {
      // Try to reach Firebase
      await FirebaseDatabase.instance.ref('.info/connected').get();
      _isOnline = true;
      _connectivityController?.add(true);
      return true;
    } catch (e) {
      _isOnline = false;
      _connectivityController?.add(false);
      return false;
    }
  }

  /// Get connectivity stream
  static Stream<bool> get connectivityStream {
    return _connectivityController?.stream ?? Stream.value(true);
  }

  /// Get current online status
  static bool get isOnline => _isOnline;

  /// Save task offline
  static Future<void> saveTaskOffline(CleaningTask task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString(_offlineTasksKey) ?? '[]';
      final tasks = List<Map<String, dynamic>>.from(jsonDecode(tasksJson));
      
      tasks.add(task.toMap());
      await prefs.setString(_offlineTasksKey, jsonEncode(tasks));
      
      // Add to sync queue
      await addToSyncQueue({
        'type': 'task',
        'action': 'create',
        'data': task.toMap(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving task offline: $e');
    }
  }

  /// Get offline tasks
  static Future<List<CleaningTask>> getOfflineTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tasksJson = prefs.getString(_offlineTasksKey) ?? '[]';
      final tasks = List<Map<String, dynamic>>.from(jsonDecode(tasksJson));
      
      return tasks.map((task) => CleaningTask.fromMap('', task)).toList();
    } catch (e) {
      debugPrint('Error getting offline tasks: $e');
      return [];
    }
  }

  /// Save notification offline
  static Future<void> saveNotificationOffline(AppNotification notification) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_offlineNotificationsKey) ?? '[]';
      final notifications = List<Map<String, dynamic>>.from(jsonDecode(notificationsJson));
      
      notifications.add(notification.toMap());
      await prefs.setString(_offlineNotificationsKey, jsonEncode(notifications));
    } catch (e) {
      debugPrint('Error saving notification offline: $e');
    }
  }

  /// Get offline notifications
  static Future<List<AppNotification>> getOfflineNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson = prefs.getString(_offlineNotificationsKey) ?? '[]';
      final notifications = List<Map<String, dynamic>>.from(jsonDecode(notificationsJson));
      
      return notifications.map((notif) => AppNotification.fromMap('', notif)).toList();
    } catch (e) {
      debugPrint('Error getting offline notifications: $e');
      return [];
    }
  }

  /// Save issue offline
  static Future<void> saveIssueOffline(Issue issue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final issuesJson = prefs.getString(_offlineIssuesKey) ?? '[]';
      final issues = List<Map<String, dynamic>>.from(jsonDecode(issuesJson));
      
      issues.add(issue.toMap());
      await prefs.setString(_offlineIssuesKey, jsonEncode(issues));
      
      // Add to sync queue
      await addToSyncQueue({
        'type': 'issue',
        'action': 'create',
        'data': issue.toMap(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving issue offline: $e');
    }
  }

  /// Get offline issues
  static Future<List<Issue>> getOfflineIssues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final issuesJson = prefs.getString(_offlineIssuesKey) ?? '[]';
      final issues = List<Map<String, dynamic>>.from(jsonDecode(issuesJson));
      
      return issues.map((issue) => Issue.fromMap('', issue)).toList();
    } catch (e) {
      debugPrint('Error getting offline issues: $e');
      return [];
    }
  }

  /// Add action to sync queue
  static Future<void> addToSyncQueue(Map<String, dynamic> action) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey) ?? '[]';
      final queue = List<Map<String, dynamic>>.from(jsonDecode(queueJson));
      
      queue.add(action);
      await prefs.setString(_syncQueueKey, jsonEncode(queue));
    } catch (e) {
      debugPrint('Error adding to sync queue: $e');
    }
  }

  /// Get sync queue
  static Future<List<Map<String, dynamic>>> getSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_syncQueueKey) ?? '[]';
      return List<Map<String, dynamic>>.from(jsonDecode(queueJson));
    } catch (e) {
      debugPrint('Error getting sync queue: $e');
      return [];
    }
  }

  /// Clear sync queue
  static Future<void> clearSyncQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_syncQueueKey);
    } catch (e) {
      debugPrint('Error clearing sync queue: $e');
    }
  }

  /// Sync offline data with server
  static Future<void> syncData() async {
    if (!_isOnline) return;
    
    try {
      final syncQueue = await getSyncQueue();
      final database = FirebaseDatabase.instance;
      
      for (final action in syncQueue) {
        try {
          switch (action['type']) {
            case 'task':
              if (action['action'] == 'create') {
                await database.ref('tasks').push().set(action['data']);
              }
              break;
            case 'issue':
              if (action['action'] == 'create') {
                await database.ref('issues').push().set(action['data']);
              }
              break;
          }
        } catch (e) {
          debugPrint('Error syncing action: $e');
        }
      }
      
      // Clear sync queue after successful sync
      await clearSyncQueue();
      
      // Update last sync time
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      
    } catch (e) {
      debugPrint('Error during sync: $e');
    }
  }

  /// Get last sync time
  static Future<DateTime?> getLastSyncTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncJson = prefs.getString(_lastSyncKey);
      if (lastSyncJson != null) {
        return DateTime.parse(lastSyncJson);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last sync time: $e');
      return null;
    }
  }

  /// Clear all offline data
  static Future<void> clearOfflineData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_offlineTasksKey);
      await prefs.remove(_offlineNotificationsKey);
      await prefs.remove(_offlineIssuesKey);
      await prefs.remove(_syncQueueKey);
      await prefs.remove(_lastSyncKey);
    } catch (e) {
      debugPrint('Error clearing offline data: $e');
    }
  }

  /// Get offline data statistics
  static Future<Map<String, int>> getOfflineStats() async {
    try {
      final tasks = await getOfflineTasks();
      final notifications = await getOfflineNotifications();
      final issues = await getOfflineIssues();
      final syncQueue = await getSyncQueue();
      
      return {
        'tasks': tasks.length,
        'notifications': notifications.length,
        'issues': issues.length,
        'sync_queue': syncQueue.length,
      };
    } catch (e) {
      debugPrint('Error getting offline stats: $e');
      return {};
    }
  }

  /// Force sync now
  static Future<void> forceSync() async {
    final wasOnline = _isOnline;
    _isOnline = await checkConnectivity();
    
    if (_isOnline) {
      await syncData();
    }
    
    if (!wasOnline && _isOnline) {
      // Came back online, sync all data
      await syncData();
    }
  }

  /// Dispose offline service
  static void dispose() {
    _syncTimer?.cancel();
    _connectivityController?.close();
  }

  

  /// Handle online/offline transitions
  static void handleConnectivityChange(bool isOnline) {
    _isOnline = isOnline;
    _connectivityController?.add(isOnline);
    
    if (isOnline) {
      // Came back online, trigger sync
      Future.delayed(Duration(seconds: 2), () {
        syncData();
      });
    }
  }
}

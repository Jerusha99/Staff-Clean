import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/cleaning_task.dart';
import '../models/user_data.dart';
import '../models/shift.dart'; // Import Shift model
import '../models/attendance.dart'; // Import Attendance model
import '../models/app_notification.dart'; // Import AppNotification model
import '../models/issue.dart'; // Import Issue model

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // User registration
  Future<User?> registerWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // User login
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // User logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Save user data to Realtime Database
  Future<void> saveUserData(String uid, String email, String role, {String? name, String? phone, String? address, String? profileImageUrl}) async {
    await _database.ref('users').child(uid).set({
      'email': email,
      'role': role,
      'name': name,
      'phone': phone,
      'address': address,
      'profileImageUrl': profileImageUrl,
      'createdAt': ServerValue.timestamp,
    });
  }

  // Get user role from Realtime Database
  Future<String?> getUserRole(String uid) async {
    try {
      DataSnapshot snapshot = await _database.ref('users').child(uid).get();
      if (snapshot.exists) {
        return (snapshot.value as Map?)?['role'] as String?;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get all users
  Stream<List<AppUserData>> getUsers() {
    return _database.ref('users').onValue.map((event) {
      final List<AppUserData> users = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          users.add(AppUserData.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return users;
    });
  }

  // Get staff members
  Stream<List<AppUserData>> getStaffMembers() {
    return getUsers().map((users) => users.where((user) => user.role == 'staff').toList());
  }

  // Realtime metrics (counts)
  Stream<int> getTasksCount() {
    return _database.ref('tasks').onValue.map((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        return data.length;
      }
      return 0;
    });
  }

  Stream<int> getTasksCountByStatus(CleaningStatus status) {
    return _database.ref('tasks').onValue.map((event) {
      final data = event.snapshot.value;
      int count = 0;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          if ((map['status'] as String?) == status.name) {
            count++;
          }
        });
      }
      return count;
    });
  }

  Stream<int> getStaffCount() {
    return _database.ref('users').orderByChild('role').equalTo('staff').onValue.map((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        return data.length;
      }
      return 0;
    });
  }

  // Add a cleaning task to Realtime Database
  Future<void> addTask(CleaningTask task) async {
    // Prevent duplicates using compositeKey
    final key = _computeCompositeKey(task);
    final existing = await _database.ref('tasks').orderByChild('compositeKey').equalTo(key).get();
    if (existing.exists && existing.value is Map) {
      return; // Duplicate detected: skip creating another identical task
    }
    final map = task.toMap();
    map['compositeKey'] = key;
    await _database.ref('tasks').push().set(map);
  }

  // Get all tasks from Realtime Database
  Stream<List<CleaningTask>> getTasks() {
    return _database.ref('tasks').onValue.map((event) {
      final List<CleaningTask> tasks = [];
      final seen = <String>{};
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          final task = CleaningTask.fromMap(key, map);
          final composite = map['compositeKey'] as String? ?? _computeCompositeKey(task);
          if (!seen.contains(composite)) {
            seen.add(composite);
            tasks.add(task);
          }
        });
      }
      return tasks;
    });
  }

  // Get tasks for a specific staff member
  Stream<List<CleaningTask>> getStaffTasks(String staffId) {
    return _database.ref('tasks').orderByChild('assignedTo').equalTo(staffId).onValue.map((event) {
      final List<CleaningTask> tasks = [];
      final seen = <String>{};
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          final map = Map<String, dynamic>.from(value as Map);
          final task = CleaningTask.fromMap(key, map);
          final composite = map['compositeKey'] as String? ?? _computeCompositeKey(task);
          if (!seen.contains(composite)) {
            seen.add(composite);
            tasks.add(task);
          }
        });
      }
      return tasks;
    });
  }

  // Update a cleaning task in Realtime Database
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    await _database.ref('tasks').child(taskId).update(updates);
  }

  // Delete a cleaning task from Realtime Database
  Future<void> deleteTask(String taskId) async {
    await _database.ref('tasks').child(taskId).remove();
  }

  // Delete user from Firebase Authentication and Realtime Database
  Future<void> deleteUser(String uid) async {
    try {
      await _database.ref('users').child(uid).remove();
    } catch (e) {
      rethrow;
    }
  }

  // Update user data in Realtime Database
  Future<void> updateUserData(String uid, Map<String, dynamic> updates) async {
    await _database.ref('users').child(uid).update(updates);
  }

  // Save FCM device token to user data
  Future<void> saveDeviceToken(String uid, String? token) async {
    if (token != null) {
      await _database.ref('users').child(uid).update({'fcmToken': token});
    }
  }

  // Add a staff shift
  Future<void> addShift(Shift shift) async {
    await _database.ref('shifts').push().set(shift.toMap());
  }

  // Get shifts for a specific staff member
  Stream<List<Shift>> getStaffShifts(String userId) {
    return _database.ref('shifts').orderByChild('userId').equalTo(userId).onValue.map((event) {
      final List<Shift> shifts = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          shifts.add(Shift.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return shifts;
    });
  }

  // Get all shifts (for admin)
  Stream<List<Shift>> getAllShifts() {
    return _database.ref('shifts').onValue.map((event) {
      final List<Shift> shifts = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          shifts.add(Shift.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return shifts;
    });
  }

  // Update a staff shift
  Future<void> updateShift(String shiftId, Map<String, dynamic> updates) async {
    await _database.ref('shifts').child(shiftId).update(updates);
  }

  // Record staff check-in
  Future<void> recordCheckIn(String userId, {DateTime? checkInTime}) async {
    final today = checkInTime ?? DateTime.now();
    final attendanceRef = _database.ref('attendance').push();
    final attendance = Attendance(
      id: attendanceRef.key!,
      userId: userId,
      checkInTime: today,
      date: DateTime(today.year, today.month, today.day), // Date only
    );
    await attendanceRef.set(attendance.toMap()
      ..['timestamp'] = ServerValue.timestamp,
    );
  }

  // Record staff check-out
  Future<void> recordCheckOut(String attendanceId, {DateTime? checkOutTime}) async {
    await _database.ref('attendance').child(attendanceId).update({
      'checkOutTime': (checkOutTime ?? DateTime.now()).toIso8601String(),
    });
  }

  // Get daily attendance for a staff member
  Stream<Attendance?> getDailyAttendance(String userId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _database
        .ref('attendance')
        .orderByChild('userId')
        .equalTo(userId)
        .onValue
        .map((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        for (var entry in data.entries) {
          final attendance = Attendance.fromMap(entry.key, Map<String, dynamic>.from(entry.value as Map));
          if (attendance.date.isAtSameMomentAs(startOfDay) || (attendance.date.isAfter(startOfDay) && attendance.date.isBefore(endOfDay))) {
            return attendance;
          }
        }
      }
      return null;
    });
  }

  // Get weekly attendance for all staff
  Stream<List<Attendance>> getWeeklyAttendance() {
    final today = DateTime.now();
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    return _database
        .ref('attendance')
        .orderByChild('timestamp')
        .startAt(sevenDaysAgo.millisecondsSinceEpoch)
        .endAt(today.millisecondsSinceEpoch)
        .onValue
        .map((event) {
      final List<Attendance> attendanceList = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          attendanceList.add(Attendance.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return attendanceList;
    });
  }



  // Get single user data from Realtime Database
  Future<AppUserData?> getUserData(String uid) async {
    try {
      DataSnapshot snapshot = await _database.ref('users').child(uid).get();
      if (snapshot.exists) {
        return AppUserData.fromMap(uid, Map<String, dynamic>.from(snapshot.value as Map));
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Get user data as stream
  Stream<AppUserData?> getUserDataStream(String uid) {
    return _database.ref('users').child(uid).onValue.map((event) {
      if (event.snapshot.exists) {
        return AppUserData.fromMap(uid, Map<String, dynamic>.from(event.snapshot.value as Map));
      } else {
        return null;
      }
    });
  }

  // Add a notification
  Future<void> addNotification(AppNotification notification) async {
    await _database.ref('notifications').push().set(notification.toMap());
  }

  // Get notifications for a specific user
  Stream<List<AppNotification>> getNotificationsForUser(String userId) {
    return _database.ref('notifications').orderByChild('recipientUserId').equalTo(userId).onValue.map((event) {
      final List<AppNotification> notifications = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          notifications.add(AppNotification.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return notifications;
    });
  }

  // Mark a notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    await _database.ref('notifications').child(notificationId).update({'read': true});
  }

  // Mark a notification request as read
  Future<void> markNotificationRequestAsRead(String requestId) async {
    await _database.ref('notification_requests').child(requestId).update({'read': true});
  }

  // Report an issue
  Future<void> reportIssue(Issue issue) async {
    await _database.ref('issues').push().set(issue.toMap());
  }

  // Get all issues
  Stream<List<Issue>> getIssues() {
    return _database.ref('issues').onValue.map((event) {
      final List<Issue> issues = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          issues.add(Issue.fromMap(key, Map<String, dynamic>.from(value as Map)));
        });
      }
      return issues;
    });
  }

  // Update issue status
  Future<void> updateIssueStatus(String issueId, IssueStatus status) async {
    await _database.ref('issues').child(issueId).update({'status': status.name});
  }

  // Send notification
  Future<void> sendNotification({
    required String title,
    required String body,
    String? userId,
  }) async {
    try {
      final request = {
        'title': title,
        'body': body,
        'userId': userId, // If null, send to all
        'createdAt': ServerValue.timestamp,
      };
      await _database.ref('notification_requests').push().set(request);

      // Create individual notifications for staff
      List<String> recipientIds = [];
      if (userId != null) {
        recipientIds = [userId];
      } else {
        // Get all staff user IDs
        final staffSnapshot = await _database.ref('users').orderByChild('role').equalTo('staff').once();
        if (staffSnapshot.snapshot.value != null && staffSnapshot.snapshot.value is Map) {
          (staffSnapshot.snapshot.value as Map).forEach((key, value) {
            recipientIds.add(key);
          });
        }
      }

      // Create notification for each recipient
      for (String recipientId in recipientIds) {
        final notification = {
          'title': title,
          'message': body,
          'recipientUserId': recipientId,
          'createdAt': ServerValue.timestamp,
          'read': false,
        };
        await _database.ref('notifications').push().set(notification);
      }

      await logAdminActivity('Sent Notification', {
        'title': title,
        'body': body,
        'userId': userId ?? 'all',
      });
    } catch (e) {
      // Handle or log the error
    }
  }

  // Get all notification requests
  Stream<List<Map<String, dynamic>>> getNotificationRequests({String? userId}) {
    Query query = _database.ref('notification_requests');
    if (userId != null) {
      query = query.orderByChild('userId').equalTo(userId);
    }
    return query.onValue.map((event) {
      final List<Map<String, dynamic>> requests = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          requests.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map),
          });
        });
      }
      return requests;
    });
  }

  // Log admin activity
  Future<void> logAdminActivity(String action, Map<String, dynamic> details) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final log = {
          'adminId': user.uid,
          'adminEmail': user.email,
          'action': action,
          'timestamp': ServerValue.timestamp,
          'details': details,
        };
        await _database.ref('audit_logs').push().set(log);
      }
    } catch (e) {
      // Handle or log the error
    }
  }

  // Get all audit logs
  Stream<List<Map<String, dynamic>>> getAuditLogs() {
    return _database.ref('audit_logs').onValue.map((event) {
      final List<Map<String, dynamic>> logs = [];
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        data.forEach((key, value) {
          logs.add({
            'id': key,
            ...Map<String, dynamic>.from(value as Map),
          });
        });
      }
      return logs;
    });
  }

  // Change user password
  Future<void> changePassword(String currentPassword, String newPassword) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final cred = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
        await user.reauthenticateWithCredential(cred);
        await user.updatePassword(newPassword);
        await logAdminActivity('Changed Password', {'userId': user.uid});
      } else {
        throw 'No user is currently signed in.';
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Helper to compute a composite key for deduplication
  String _computeCompositeKey(CleaningTask t) {
    final day = DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day).millisecondsSinceEpoch;
    return '${t.title.trim().toLowerCase()}|${t.area.name}|$day|${t.assignedTo}';
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided for that user.';
      default:
        return 'An unknown error occurred.';
    }
  }
}


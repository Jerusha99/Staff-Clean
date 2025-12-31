import 'package:staff_cleaning/services/notification_service.dart';
import 'package:staff_cleaning/utils/theme.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Import Firebase Messaging
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/dashboard_screen.dart';
import 'screens/tasks_screen.dart';
import 'screens/history_screen.dart';
import 'screens/staff_management_screen.dart'; // Import StaffManagementScreen
import 'package:staff_cleaning/services/firebase_service.dart';
import 'package:staff_cleaning/screens/profile_editing_screen.dart';
import 'package:staff_cleaning/screens/admin_report_screen.dart';
import 'package:staff_cleaning/screens/admin_settings_screen.dart';
import 'package:staff_cleaning/screens/shift_management_screen.dart';
import 'package:staff_cleaning/screens/attendance_tracking_screen.dart';
import 'package:staff_cleaning/screens/recurring_task_management_screen.dart';
import 'package:staff_cleaning/services/task_scheduling_service.dart';

import 'package:staff_cleaning/screens/staff_settings_screen.dart';
import 'package:staff_cleaning/screens/about_screen.dart';
import 'screens/notification_history_screen.dart';
import 'package:staff_cleaning/screens/chatbot_screen.dart';
import 'package:staff_cleaning/models/user_role.dart'; // Import UserRole enum
import 'package:staff_cleaning/widgets/auth_wrapper.dart'; // Import AuthWrapper
import 'package:shared_preferences/shared_preferences.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
  
  // Initialize local notifications for background
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
  
  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  
  // Show notification when app is in background
  if (message.notification != null) {
    await flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'New Notification',
      message.notification?.body ?? 'You have a new message',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'staff_cleaning_channel',
          'Staff Cleaning Notifications',
          channelDescription: 'Notifications from Staff Cleaning App',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
      ),
    );
  }
}

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        // Initialize Firebase with timeout
        await Firebase.initializeApp().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            throw Exception('Firebase initialization timeout');
          },
        );

        // Explicitly create an Android Notification Channel
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          'staff_cleaning_channel', // id
          'Staff Cleaning Notifications', // title
          description: 'Notifications from Staff Cleaning App', // description
          importance: Importance.max,
        );

        // Get the FlutterLocalNotificationsPlugin instance
        final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
            FlutterLocalNotificationsPlugin();

        // Create the Android notification channel
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);

// Initialize NotificationService
        final NotificationService notificationService = NotificationService();
        await notificationService.init().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('Notification service init timeout');
          },
        );

// Request notification permissions
        final bool notificationsEnabled = await notificationService.requestPermissions();
        debugPrint('Notifications enabled: $notificationsEnabled');
        
        // Removed startup test notification to avoid unsolicited alerts at launch.

        // Initialize Firebase Messaging
        FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
        await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        ).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('Firebase messaging init timeout');
          },
        );

        // Silence all debug prints (including plugin prints) in debug console
        // debugPrint = (String? message, {int? wrapWidth}) {};
        runApp(const StaffCleaningApp());
      } catch (e, stackTrace) {
        // If initialization fails, still run the app but log the error
        debugPrint('Initialization error: $e');
        debugPrint('Stack trace: $stackTrace');
        runApp(const StaffCleaningApp());
      }
    },
    (Object error, StackTrace stack) {
      if (kReleaseMode) {
        // In release, avoid noisy logs
        return;
      } else {
        // In debug/profile, still surface uncaught errors to help development
        // print('Uncaught error: $error'); // Removed print statement
      }
    },

  );
}

class StaffCleaningApp extends StatelessWidget {
  const StaffCleaningApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Staff Cleaning',
      debugShowCheckedModeBanner: false, // Remove debug banner
      theme: AppTheme.lightTheme,
      home: const AuthWrapper(), // Check auth state and redirect accordingly
    );
  }
}

class MainScreen extends StatefulWidget {
  final UserRole userRole;
  final String? userId;
  final int? initialIndex;
  const MainScreen({required this.userRole, this.userId, this.initialIndex})
    : super(key: const ValueKey('MainScreen'));

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final TaskSchedulingService _taskSchedulingService = TaskSchedulingService();
  String _userName = 'Loading...';
  String _userEmail = '';

  late List<Widget> _widgetOptions;
  late List<String> _titles;
  late List<BottomNavigationBarItem> _bottomNavigationBarItems;

@override
  void initState() {
    super.initState();
    _loadUserData();
    _initFirebaseMessaging(); // Initialize Firebase Messaging
    _initTaskScheduling(); // Initialize task scheduling
    _selectedIndex = widget.initialIndex ?? 0;
    _initializeScreens();
  }

  @override
  void dispose() {
    _taskSchedulingService.stopTaskScheduling();
    super.dispose();
  }

  void _initializeScreens() {
    if (widget.userRole == UserRole.admin) {
      _widgetOptions = <Widget>[
        DashboardScreen(
          userRole: widget.userRole,
          userId: widget.userId,
          userName: _userName,
          userEmail: _userEmail,
        ), // Admin Dashboard
        TasksScreen(
          userRole: widget.userRole,
          userId: widget.userId,
        ), // All Tasks
        HistoryScreen(
          userRole: widget.userRole,
          userId: widget.userId,
        ), // All History
        const AboutScreen(), // About
      ];
      _titles = <String>[
        'Admin Dashboard',
        'All Tasks',
        'All History',
        'About',
      ];
      _bottomNavigationBarItems = const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_circle_outline_rounded),
          label: 'Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.info_rounded),
          label: 'About',
        ),
      ];
    } else {
      // UserRole.staff
      _widgetOptions = <Widget>[
        DashboardScreen(
          userRole: widget.userRole,
          userId: widget.userId,
          userName: _userName,
          userEmail: _userEmail,
        ), // Staff Personal Dashboard
        TasksScreen(
          userRole: widget.userRole,
          userId: widget.userId,
        ), // My Tasks
        HistoryScreen(
          userRole: widget.userRole,
          userId: widget.userId,
        ), // My History
        const AboutScreen(), // About
      ];
      _titles = <String>[
        'Staff Dashboard',
        'My Tasks',
        'My History',
        'About',
      ];
      _bottomNavigationBarItems = const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_rounded),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.check_circle_outline_rounded),
          label: 'My Tasks',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_rounded),
          label: 'My History',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.info_rounded),
          label: 'About',
        ),
      ];
    }
  }

  Future<void> _loadUserData() async {
    if (widget.userId != null) {
      final userData = await _firebaseService.getUserData(widget.userId!);
      if (userData != null) {
        setState(() {
          _userName = userData.name ?? userData.email;
          _userEmail = userData.email;
          // Reinitialize screens with updated user data
          _initializeScreens();
        });
      }
    }
  }

void _initTaskScheduling() {
    if (widget.userRole == UserRole.admin) {
      _taskSchedulingService.startTaskScheduling();
    }
  }

  Future<void> _initFirebaseMessaging() async {
    NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // print('User granted permission'); // Removed print statement
      String? token = await FirebaseMessaging.instance.getToken();
      // print('FCM Token: $token'); // Removed print statement
      if (token != null && widget.userId != null) {
        await _firebaseService.saveDeviceToken(widget.userId!, token);
      }
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      // print('User granted provisional permission'); // Removed print statement
    } else {
      // print('User declined or has not accepted permission'); // Removed print statement
    }

    // Initialize notification service for foreground messages
    final NotificationService notificationService = NotificationService();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      // print('Got a message whilst in the foreground!'); // Removed print statement
      // print('Message data: ${message.data}'); // Removed print statement

      if (message.notification != null) {
        // Show local notification when app is in foreground
        notificationService.showNotification(
          message.notification?.title ?? 'New Notification',
          message.notification?.body ?? 'You have a new message',
        );
      }
    });

    // Handle messages when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // print('Message clicked!'); // Removed print statement
      // You can navigate to a specific screen here based on message data
    });

    // Check if app was opened from notification when launched
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      // print('App opened from notification!'); // Removed print statement
      // You can navigate to a specific screen here based on message data
    }
  }

  void onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
             UserAccountsDrawerHeader(
               accountName: Text(_userName, style: Theme.of(context).textTheme.titleLarge),
               accountEmail: Text(_userEmail, style: Theme.of(context).textTheme.bodyMedium),
               currentAccountPicture: CircleAvatar(
                 backgroundColor: Theme.of(context).colorScheme.secondary,
                 child: const Icon(Icons.person, color: Colors.white),
               ),
               decoration: BoxDecoration(
                 gradient: LinearGradient(
                   colors: [
                     AppTheme.primaryColor.withValues(alpha: 0.8),
                     AppTheme.secondaryColor.withValues(alpha: 0.6),
                   ],
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                 ),
               ),
             ),
            if (widget.userRole == UserRole.admin) ...[
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedIndex = 0;
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_alt_rounded),
                title: const Text('Staff Management'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const StaffManagementScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('Shift Management'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShiftManagementScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.fingerprint),
                title: const Text('Attendance Tracking'),
                onTap: () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AttendanceTrackingScreen()),
                  );
                },
              ),

              ListTile(
                 leading: const Icon(Icons.repeat),
                 title: const Text('Recurring Tasks'),
                 onTap: () {
                   Navigator.pop(context); // Close the drawer
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const RecurringTaskManagementScreen()),
                   );
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.report),
                 title: const Text('Admin Task Report'),
                 onTap: () {
                   Navigator.pop(context); // Close the drawer
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const AdminReportScreen()),
                   );
                 },
               ),
             ] else ...[
                // Staff-specific drawer items
               ListTile(
                 leading: const Icon(Icons.home),
                 title: const Text('Home'),
                 onTap: () {
                   Navigator.pop(context);
                   setState(() {
                     _selectedIndex = 0; // Dashboard
                   });
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.check_circle_outline_rounded),
                 title: const Text('Tasks'),
                 onTap: () {
                   Navigator.pop(context);
                   setState(() {
                     _selectedIndex = 1; // My Tasks
                   });
                 },
               ),
               ListTile(
                 leading: const Icon(Icons.chat_rounded),
                 title: const Text('Help'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                   );
                 },
               ),
             ],
             const Divider(),
             ListTile(
               leading: const Icon(Icons.notifications),
               title: const Text('Notification History'),
               onTap: () {
                 Navigator.pop(context); // Close the drawer
                 Navigator.push(
                   context,
                   MaterialPageRoute(
                     builder: (context) => NotificationHistoryScreen(
                       userRole: widget.userRole,
                       userId: widget.userId,
                     ),
                   ),
                 );
               },
             ),
             if (widget.userRole == UserRole.admin)
               ListTile(
                 leading: const Icon(Icons.settings),
                 title: const Text('Settings'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const AdminSettingsScreen()),
                   );
                 },
               )
             else
               ListTile(
                 leading: const Icon(Icons.settings),
                 title: const Text('Settings'),
                 onTap: () {
                   Navigator.pop(context);
                   Navigator.push(
                     context,
                     MaterialPageRoute(builder: (context) => const StaffSettingsScreen()),
                   );
                 },
               ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                // Clear local storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // Sign out from Firebase
                await _firebaseService.signOut();
                if (!context.mounted) return;
                // Navigate to login screen and clear navigation stack
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthWrapper()),
                  (Route<dynamic> route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: _bottomNavigationBarItems,
          currentIndex: _selectedIndex,
          onTap: onItemTapped,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
          selectedFontSize: 12,
          unselectedFontSize: 11,
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../screens/login_screen.dart';
import '../services/firebase_service.dart';
import '../models/user_role.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  StreamSubscription<User?>? _authSubscription;

@override
  void initState() {
    super.initState();
    _checkAuthState();
    
    // Add a timeout to prevent infinite loading
    Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
        debugPrint('AuthWrapper: Loading timeout, showing login screen');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _navigateToMainScreen(User user, String role) async {
    final userRole = role == 'admin' ? UserRole.admin : UserRole.staff;
    // Save role to local storage for faster access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userRole', role);
    await prefs.setString('userId', user.uid);
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainScreen(
            userRole: userRole,
            userId: user.uid,
          ),
        ),
      );
    }
  }

  Future<void> _handleSignedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthState() async {
    try {
      // Check current user immediately
      final currentUser = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${currentUser?.uid}');
      
      if (currentUser != null) {
        // User is signed in, get their role with timeout
        final role = await _firebaseService.getUserRole(currentUser.uid).timeout(
          const Duration(seconds: 10),
          onTimeout: () => null,
        );
        debugPrint('User role: $role');
        
        if (role != null) {
          await _navigateToMainScreen(currentUser, role);
          return;
        } else {
          // Role not found or timeout, sign out
          await _firebaseService.signOut();
          await _handleSignedOut();
          return;
        }
      } else {
        // No user signed in
        debugPrint('No user signed in');
        await _handleSignedOut();
      }

      // Listen to auth state changes for future logins/logouts
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        debugPrint('Auth state changed: ${user?.uid}');
        
        if (user != null) {
          // User is signed in, get their role with timeout
          final role = await _firebaseService.getUserRole(user.uid).timeout(
            const Duration(seconds: 10),
            onTimeout: () => null,
          );
          debugPrint('User role from stream: $role');
          
          if (role != null) {
            await _navigateToMainScreen(user, role);
          } else {
            // Role not found or timeout, sign out and show login
            await _firebaseService.signOut();
            await _handleSignedOut();
          }
        } else {
          // User signed out
          debugPrint('User signed out from stream');
          await _handleSignedOut();
        }
      });
    } catch (e) {
      // If auth check fails, show login screen
      debugPrint('Auth check error: $e');
      await _handleSignedOut();
    } finally {
      // Ensure loading state is updated
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return const LoginScreen();
  }
}


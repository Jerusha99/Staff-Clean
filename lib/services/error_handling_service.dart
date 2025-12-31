import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


import 'package:connectivity_plus/connectivity_plus.dart';

class ErrorHandlingService {
  static final Map<String, int> _retryAttempts = {};
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  /// Handle Firebase Auth exceptions
  static String handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak. Please choose a stronger password.';
      case 'email-already-in-use':
        return 'An account already exists for this email address.';
      case 'user-not-found':
        return 'No user found for this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      case 'session-expired':
        return 'Your session has expired. Please log in again.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please log in again.';
      default:
        return 'An authentication error occurred: ${e.message}';
    }
  }

  /// Handle Firebase Database exceptions
  static String handleDatabaseException(Exception e) {
    if (e.toString().contains('permission-denied')) {
      return 'You don\'t have permission to perform this action.';
    } else if (e.toString().contains('unavailable')) {
      return 'The service is currently unavailable. Please try again later.';
    } else if (e.toString().contains('timeout')) {
      return 'The operation timed out. Please check your connection and try again.';
    } else if (e.toString().contains('network-error')) {
      return 'Network error. Please check your internet connection.';
    } else if (e.toString().contains('disconnected')) {
      return 'Connection to server was lost. Please check your internet connection.';
    } else {
      return 'A database error occurred: ${e.toString()}';
    }
  }

  /// Handle general exceptions
  static String handleGeneralException(Exception e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your network settings.';
    } else if (e is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (e is FormatException) {
      return 'Data format error. Please try again.';
    } else {
      return 'An unexpected error occurred: ${e.toString()}';
    }
  }

  /// Execute operation with retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation,
    String operationName, {
    int? maxRetries,
    Duration? retryDelay,
  }) async {
    final retries = maxRetries ?? _maxRetries;
    final delay = retryDelay ?? _retryDelay;
    final attemptKey = operationName;

    for (int attempt = 0; attempt <= retries; attempt++) {
      try {
        final result = await operation();
        // Reset retry attempts on success
        _retryAttempts.remove(attemptKey);
        return result;
      } catch (e) {
        if (attempt == retries) {
          _retryAttempts.remove(attemptKey);
          rethrow;
        }

        // Increment retry attempts
        _retryAttempts[attemptKey] = (_retryAttempts[attemptKey] ?? 0) + 1;

        // Wait before retrying
        await Future.delayed(delay * (attempt + 1));
      }
    }

    throw Exception('Operation failed after $retries retries');
  }

  /// Check if operation should be retried
  static bool shouldRetry(Exception e) {
    if (e is SocketException) return true;
    if (e is TimeoutException) return true;
    if (e is FirebaseAuthException) {
      return ['network-request-failed', 'timeout', 'unavailable'].contains(e.code);
    }
    final eString = e.toString();
    if (eString.contains('timeout') || eString.contains('network-error') || eString.contains('unavailable')) {
      return true;
    }
    return false;
  }

  /// Get retry attempts count
  static int getRetryAttempts(String operationName) {
    return _retryAttempts[operationName] ?? 0;
  }

  /// Reset retry attempts
  static void resetRetryAttempts(String operationName) {
    _retryAttempts.remove(operationName);
  }

  /// Show error dialog
  static void showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'DISMISS',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar
  static void showInfoSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Check internet connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  /// Monitor connectivity changes
  static Stream<bool> monitorConnectivity() {
    return Connectivity().onConnectivityChanged.map((result) {
      return !result.contains(ConnectivityResult.none);
    });
  }

  /// Log error for debugging
  static void logError(String operation, dynamic error, StackTrace? stackTrace) {
    debugPrint('Error in $operation: $error');
    if (stackTrace != null) {
      debugPrint('Stack trace: $stackTrace');
    }
    
    // In a real app, you would send this to a logging service
    // like Firebase Crashlytics, Sentry, etc.
  }

  /// Handle offline mode
  static void handleOfflineMode(BuildContext context) {
    showErrorSnackBar(
      context,
      'You are currently offline. Some features may not be available.',
    );
  }

  /// Handle online mode
  static void handleOnlineMode(BuildContext context) {
    showSuccessSnackBar(
      context,
      'You are back online. Syncing data...',
    );
  }

  /// Validate network operation
  static Future<bool> validateNetworkOperation(BuildContext context) async {
    final isConnected = await checkConnectivity();
    if (!isConnected) {
      final currentContext = context;
      if (currentContext.mounted) {
        handleOfflineMode(currentContext);
      }
      return false;
    }
    return true;
  }

  /// Create error widget
  static Widget createErrorWidget({
    required String message,
    VoidCallback? onRetry,
    IconData? icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Create loading widget with message
  static Widget createLoadingWidget({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Create empty state widget
  static Widget createEmptyStateWidget({
    required String message,
    IconData? icon,
    VoidCallback? onAction,
    String? actionText,
  }) {
    final actionButton = onAction != null && actionText != null
        ? ElevatedButton(
            onPressed: onAction,
            child: Text(actionText),
          )
        : null;
        
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            if (actionButton != null) ...[
              const SizedBox(height: 16),
              actionButton,
            ],
          ],
        ),
      ),
    );
  }
}

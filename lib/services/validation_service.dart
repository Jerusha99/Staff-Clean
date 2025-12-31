
import 'package:flutter/material.dart';

class ValidationService {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Basic email regex
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }
    
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }
    
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Password must contain at least one special character';
    }
    
    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (value.length > 50) {
      return 'Name cannot exceed 50 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return 'Name can only contain letters and spaces';
    }
    
    return null;
  }

  // Phone validation
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Remove all non-digit characters
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');
    
    if (digitsOnly.length < 10) {
      return 'Phone number must be at least 10 digits';
    }
    
    if (digitsOnly.length > 15) {
      return 'Phone number cannot exceed 15 digits';
    }
    
    return null;
  }

  // Task title validation
  static String? validateTaskTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Task title is required';
    }
    
    if (value.length < 3) {
      return 'Task title must be at least 3 characters long';
    }
    
    if (value.length > 100) {
      return 'Task title cannot exceed 100 characters';
    }
    
    return null;
  }

  // Task description validation
  static String? validateTaskDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Task description is required';
    }
    
    if (value.length < 10) {
      return 'Task description must be at least 10 characters long';
    }
    
    if (value.length > 500) {
      return 'Task description cannot exceed 500 characters';
    }
    
    return null;
  }

  // Address validation
  static String? validateAddress(String? value) {
    if (value == null || value.isEmpty) {
      return 'Address is required';
    }
    
    if (value.length < 5) {
      return 'Address must be at least 5 characters long';
    }
    
    if (value.length > 200) {
      return 'Address cannot exceed 200 characters';
    }
    
    return null;
  }

  // Issue description validation
  static String? validateIssueDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'Issue description is required';
    }
    
    if (value.length < 10) {
      return 'Issue description must be at least 10 characters long';
    }
    
    if (value.length > 1000) {
      return 'Issue description cannot exceed 1000 characters';
    }
    
    return null;
  }

  // Notification title validation
  static String? validateNotificationTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Notification title is required';
    }
    
    if (value.length < 3) {
      return 'Notification title must be at least 3 characters long';
    }
    
    if (value.length > 100) {
      return 'Notification title cannot exceed 100 characters';
    }
    
    return null;
  }

  // Notification body validation
  static String? validateNotificationBody(String? value) {
    if (value == null || value.isEmpty) {
      return 'Notification message is required';
    }
    
    if (value.length < 5) {
      return 'Notification message must be at least 5 characters long';
    }
    
    if (value.length > 500) {
      return 'Notification message cannot exceed 500 characters';
    }
    
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    
    if (value != password) {
      return 'Passwords do not match';
    }
    
    return null;
  }

  // General required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Length validation
  static String? validateLength(String? value, int minLength, int maxLength, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (value.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }
    
    if (value.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    
    return null;
  }

  // Numeric validation
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (double.tryParse(value) == null) {
      return '$fieldName must be a valid number';
    }
    
    return null;
  }

  // Sanitize input to prevent XSS
  static String sanitizeInput(String input) {
    // Remove potentially dangerous characters
    return input
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>'), '')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .trim();
  }

  // Validate file size (for image uploads)
  static String? validateFileSize(int fileSize, int maxSizeInMB) {
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    
    if (fileSize > maxSizeInBytes) {
      return 'File size cannot exceed $maxSizeInMB MB';
    }
    
    return null;
  }

  // Validate file type
  static String? validateFileType(String fileName, List<String> allowedExtensions) {
    final extension = fileName.split('.').last.toLowerCase();
    
    if (!allowedExtensions.contains(extension)) {
      return 'File type not allowed. Allowed types: ${allowedExtensions.join(', ')}';
    }
    
    return null;
  }

  // Validate date range
  static String? validateDateRange(DateTime? startDate, DateTime? endDate) {
    if (startDate == null || endDate == null) {
      return 'Both start and end dates are required';
    }
    
    if (endDate.isBefore(startDate)) {
      return 'End date must be after start date';
    }
    
    if (endDate.isBefore(DateTime.now())) {
      return 'End date cannot be in the past';
    }
    
    return null;
  }

  // Validate shift time
  static String? validateShiftTime(DateTime startTime, DateTime endTime) {
    if (endTime.isBefore(startTime)) {
      return 'End time must be after start time';
    }
    
    final duration = endTime.difference(startTime);
    if (duration.inHours > 12) {
      return 'Shift cannot be longer than 12 hours';
    }
    
    if (duration.inMinutes < 30) {
      return 'Shift must be at least 30 minutes long';
    }
    
    return null;
  }

  // Get password strength
  static PasswordStrength getPasswordStrength(String password) {
    int score = 0;
    
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    
    switch (score) {
      case 0:
      case 1:
        return PasswordStrength.veryWeak;
      case 2:
      case 3:
        return PasswordStrength.weak;
      case 4:
        return PasswordStrength.medium;
      case 5:
        return PasswordStrength.strong;
      case 6:
        return PasswordStrength.veryStrong;
      default:
        return PasswordStrength.veryWeak;
    }
  }

  // Get password strength color
  static Color getPasswordStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return Colors.red;
      case PasswordStrength.weak:
        return Colors.orange;
      case PasswordStrength.medium:
        return Colors.yellow;
      case PasswordStrength.strong:
        return Colors.lightGreen;
      case PasswordStrength.veryStrong:
        return Colors.green;
    }
  }

  // Get password strength text
  static String getPasswordStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.veryWeak:
        return 'Very Weak';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
      case PasswordStrength.veryStrong:
        return 'Very Strong';
    }
  }
}

enum PasswordStrength {
  veryWeak,
  weak,
  medium,
  strong,
  veryStrong,
}

import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'Cleaning Pro';
  static const String version = '1.0.0';
  static const String buildNumber = '1';
  
  // Environment
  static const String environment = kReleaseMode ? 'production' : 'development';
  static const bool isDebugMode = kDebugMode;
  static const bool isProfileMode = kProfileMode;
  static const bool isReleaseMode = kReleaseMode;
  
  // App Configuration
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration cacheDuration = Duration(hours: 1);
  static const Duration syncInterval = Duration(minutes: 5);
  static const Duration sessionTimeout = Duration(hours: 24);
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double cardBorderRadius = 12.0;
  static const double buttonBorderRadius = 30.0;
  static const double bubbleAnimationDuration = 3.0;
  static const int maxBubbleCount = 15;
  
  // Validation Rules
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 128;
  static const int minNameLength = 2;
  static const int maxNameLength = 50;
  static const int maxDescriptionLength = 500;
  static const int maxNotificationLength = 1000;
  static const int maxFileSizeMB = 10;
  
  // Performance Settings
  static const int maxCacheSizeMB = 100;
  static const int itemsPerPage = 20;
  static const Duration networkTimeout = Duration(seconds: 30);
  static const Duration animationDuration = Duration(milliseconds: 300);
  
  // Feature Flags
  static const bool enableAnimations = true;
  static const bool enableOfflineMode = true;
  static const bool enableCaching = true;
  static const bool enableAnalytics = !kDebugMode;
  static const bool enableCrashReporting = !kDebugMode;
  static const bool enablePerformanceMonitoring = !kDebugMode;
  static const bool enableDebugLogs = kDebugMode;
  static const bool enableDebugMenu = kDebugMode;
  
  // API Configuration
  static const String apiVersion = 'v1';
  static const Map<String, String> apiHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'CleaningPro/1.0.0',
  };
  
  // Firebase Configuration
  static const String firebaseProjectId = 'cleaning-app-prod';
  static const String firebaseStorageBucket = 'cleaning-app-prod.appspot.com';
  static const String firebaseDatabaseUrl = 'https://cleaning-app-prod-default-rtdb.firebaseio.com';
  
  // Notification Configuration
  static const String notificationChannelId = 'cleaning_app_notifications';
  static const String notificationChannelName = 'Cleaning App Notifications';
  static const String notificationChannelDescription = 'Notifications for cleaning tasks and updates';
  static const bool enableVibration = true;
  static const bool enableSound = true;
  
  // Security Configuration
  static const int maxLoginAttempts = 5;
  static const Duration lockoutDuration = Duration(minutes: 15);
  static const bool requireEmailVerification = true;
  static const bool enableTwoFactorAuth = false; // Future feature
  
  // Theme Configuration
  static const bool enableDarkMode = true;
  static const bool enableSystemTheme = true;
  static const String defaultTheme = 'system';
  
  // Localization
  static const String defaultLocale = 'en_US';
  static const List<String> supportedLocales = [
    'en_US',
    'es_ES',
    'fr_FR',
    'de_DE',
    'ja_JP',
  ];
  
  // File Upload Configuration
  static const List<String> allowedImageTypes = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'webp',
  ];
  
  static const List<String> allowedDocumentTypes = [
    'pdf',
    'doc',
    'docx',
    'txt',
  ];
  
  // Rate Limiting
  static const int maxApiCallsPerMinute = 100;
  static const int maxNotificationsPerHour = 10;
  static const int maxTaskCreationsPerDay = 50;
  
  // Data Retention
  static const Duration auditLogRetention = Duration(days: 90);
  static const Duration notificationRetention = Duration(days: 30);
  static const Duration taskHistoryRetention = Duration(days: 365);
  
  // Error Reporting
  static const bool enableErrorReporting = !kDebugMode;
  static const List<String> ignoredErrors = [
    'Network image load error',
    'Widget creation error',
    'Animation controller disposed',
  ];
  
  // Development Settings (Debug Only)
  static const bool enableMockData = kDebugMode;
  static const bool enableNetworkLogging = kDebugMode;
  static const bool enablePerformanceOverlay = kDebugMode;
  static const bool enableWidgetInspector = kDebugMode;
  
  // App Store Configuration
  static const String appStoreId = 'com.example.cleaningapp';
  static const String playStoreId = 'com.example.cleaningapp';
  static const String privacyPolicyUrl = 'https://example.com/privacy';
  static const String termsOfServiceUrl = 'https://example.com/terms';
  static const String supportEmail = 'support@cleaningapp.com';
  static const String supportPhone = '+1-800-CLEAN';
  
  // Social Links
  static const String websiteUrl = 'https://cleaningapp.com';
  static const String facebookUrl = 'https://facebook.com/cleaningapp';
  static const String twitterUrl = 'https://twitter.com/cleaningapp';
  static const String instagramUrl = 'https://instagram.com/cleaningapp';
  
  // Legal
  static const String copyright = '© 2024 Cleaning Pro. All rights reserved.';
  static const String companyName = 'Cleaning Pro Inc.';
  static const String companyAddress = '123 Cleaning St, Clean City, CC 12345';
  
  // Helper Methods
  static bool get isProduction => environment == 'production';
  static bool get isDevelopment => environment == 'development';
  static bool get isTesting => environment == 'testing';
  
  static String get apiBaseUrl {
    switch (environment) {
      case 'production':
        return 'https://api.cleaningapp.com';
      case 'staging':
        return 'https://staging-api.cleaningapp.com';
      case 'testing':
        return 'https://test-api.cleaningapp.com';
      default:
        return 'https://dev-api.cleaningapp.com';
    }
  }
  
  static String get webUrl {
    switch (environment) {
      case 'production':
        return 'https://cleaningapp.com';
      case 'staging':
        return 'https://staging.cleaningapp.com';
      case 'testing':
        return 'https://test.cleaningapp.com';
      default:
        return 'https://dev.cleaningapp.com';
    }
  }
  
  static Duration get timeout {
    if (kDebugMode) {
      return const Duration(seconds: 60); // Longer timeout for debugging
    }
    return const Duration(seconds: 30);
  }
  
  static int get maxRetry {
    if (kDebugMode) {
      return 1; // Fewer retries for faster debugging
    }
    return maxRetryAttempts;
  }
  
  // Validation
  static void validateConfig() {
    assert(appName.isNotEmpty, 'App name cannot be empty');
    assert(version.isNotEmpty, 'Version cannot be empty');
    assert(maxPasswordLength >= minPasswordLength, 'Max password length must be >= min');
    assert(maxNameLength >= minNameLength, 'Max name length must be >= min');
    assert(itemsPerPage > 0, 'Items per page must be > 0');
    assert(maxCacheSizeMB > 0, 'Max cache size must be > 0');
  }
}


import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class CacheService {
  static const String _cachePrefix = 'cache_';
  static const String _timestampPrefix = 'timestamp_';
  static const Duration _defaultCacheDuration = Duration(hours: 1);
  
  /// Cache data with optional expiration
  static Future<void> cacheData(
    String key,
    dynamic data, {
    Duration? duration,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cachePrefix + key;
      final timestampKey = _timestampPrefix + key;
      final expiration = duration ?? _defaultCacheDuration;
      
      // Store data
      if (data is String) {
        await prefs.setString(cacheKey, data);
      } else if (data is int) {
        await prefs.setInt(cacheKey, data);
      } else if (data is double) {
        await prefs.setDouble(cacheKey, data);
      } else if (data is bool) {
        await prefs.setBool(cacheKey, data);
      } else if (data is List<String>) {
        await prefs.setStringList(cacheKey, data);
      } else {
        // For complex objects, store as JSON string
        await prefs.setString(cacheKey, jsonEncode(data));
      }
      
      // Store timestamp
      final expiryTime = DateTime.now().add(expiration).millisecondsSinceEpoch;
      await prefs.setInt(timestampKey, expiryTime);
    } catch (e) {
      debugPrint('Error caching data: $e');
    }
  }

  /// Get cached data
  static Future<T?> getCachedData<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cachePrefix + key;
      final timestampKey = _timestampPrefix + key;
      
      // Check if data exists and is not expired
      if (!prefs.containsKey(cacheKey) || !prefs.containsKey(timestampKey)) {
        return null;
      }
      
      final expiryTime = prefs.getInt(timestampKey) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch > expiryTime) {
        // Data expired, remove it
        await removeCachedData(key);
        return null;
      }
      
      // Return data based on type
      final data = prefs.get(cacheKey);
      if (data is T) {
        return data;
      } else if (data is String && T != String) {
        // Try to parse as JSON
        try {
          return jsonDecode(data) as T?;
        } catch (e) {
          return null;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting cached data: $e');
      return null;
    }
  }

  /// Remove cached data
  static Future<void> removeCachedData(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cachePrefix + key;
      final timestampKey = _timestampPrefix + key;
      
      await prefs.remove(cacheKey);
      await prefs.remove(timestampKey);
    } catch (e) {
      debugPrint('Error removing cached data: $e');
    }
  }

  /// Clear all cached data
  static Future<void> clearAllCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith(_cachePrefix) || key.startsWith(_timestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  /// Clear expired cache entries
  static Future<void> clearExpiredCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_timestampPrefix)) {
          final expiryTime = prefs.getInt(key) ?? 0;
          if (now > expiryTime) {
            final cacheKey = key.replaceFirst(_timestampPrefix, _cachePrefix);
            await prefs.remove(key);
            await prefs.remove(cacheKey);
          }
        }
      }
    } catch (e) {
      debugPrint('Error clearing expired cache: $e');
    }
  }

  /// Check if data is cached and not expired
  static Future<bool> isDataCached(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = _cachePrefix + key;
      final timestampKey = _timestampPrefix + key;
      
      if (!prefs.containsKey(cacheKey) || !prefs.containsKey(timestampKey)) {
        return false;
      }
      
      final expiryTime = prefs.getInt(timestampKey) ?? 0;
      return DateTime.now().millisecondsSinceEpoch <= expiryTime;
    } catch (e) {
      return false;
    }
  }

  /// Cache image file
  static Future<String?> cacheImage(String url, Uint8List imageBytes) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = url.hashCode.toString();
      final imagePath = '${directory.path}/$fileName.jpg';
      
      final file = File(imagePath);
      await file.writeAsBytes(imageBytes);
      
      // Cache the file path
      await cacheData('image_$url', imagePath, duration: Duration(days: 7));
      return imagePath;
    } catch (e) {
      debugPrint('Error caching image: $e');
      return null;
    }
  }

  /// Get cached image
  static Future<File?> getCachedImage(String url) async {
    try {
      final imagePath = await getCachedData<String>('image_$url');
      if (imagePath == null) return null;
      
      final file = File(imagePath);
      return await file.exists() ? file : null;
    } catch (e) {
      debugPrint('Error getting cached image: $e');
      return null;
    }
  }

  /// Cache large data to file
  static Future<void> cacheLargeData(String key, String data) async {
    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$key.json');
      await file.writeAsString(data);
      
      // Cache the file path with timestamp
      await cacheData('file_$key', file.path, duration: Duration(days: 1));
    } catch (e) {
      debugPrint('Error caching large data: $e');
    }
  }

  /// Get cached large data from file
  static Future<String?> getCachedLargeData(String key) async {
    try {
      final filePath = await getCachedData<String>('file_$key');
      if (filePath == null) return null;
      
      final file = File(filePath);
      return await file.exists() ? await file.readAsString() : null;
    } catch (e) {
      debugPrint('Error getting cached large data: $e');
      return null;
    }
  }

  /// Get cache size
  static Future<int> getCacheSize() async {
    try {
      final directory = await getTemporaryDirectory();
      final files = await directory.list().toList();
      int totalSize = 0;
      
      for (final file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      debugPrint('Error getting cache size: $e');
      return 0;
    }
  }

  /// Clear cache if it exceeds size limit
  static Future<void> clearCacheIfExceeds(int maxSizeInBytes) async {
    try {
      final currentSize = await getCacheSize();
      if (currentSize > maxSizeInBytes) {
        await clearAllCache();
      }
    } catch (e) {
      debugPrint('Error checking cache size: $e');
    }
  }

  /// Preload common data
  static Future<void> preloadCommonData() async {
    try {
      // Clear expired cache first
      await clearExpiredCache();
      
      // Preload user data if not cached
      if (!await isDataCached('user_preferences')) {
        // Cache default user preferences
        await cacheData('user_preferences', {
          'theme': 'system',
          'notifications': true,
          'auto_sync': true,
        });
      }
    } catch (e) {
      debugPrint('Error preloading common data: $e');
    }
  }

  /// Get cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int cacheCount = 0;
      int expiredCount = 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      for (final key in keys) {
        if (key.startsWith(_timestampPrefix)) {
          cacheCount++;
          final expiryTime = prefs.getInt(key) ?? 0;
          if (now > expiryTime) {
            expiredCount++;
          }
        }
      }
      
      final totalSize = await getCacheSize();
      
      return {
        'total_entries': cacheCount,
        'expired_entries': expiredCount,
        'valid_entries': cacheCount - expiredCount,
        'total_size_bytes': totalSize,
        'total_size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      debugPrint('Error getting cache stats: $e');
      return {};
    }
  }
}

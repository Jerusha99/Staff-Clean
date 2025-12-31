import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_role.dart';


class SecurityService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Cache for user roles to reduce database calls
  static final Map<String, UserRole> _roleCache = {};
  static DateTime _lastCacheUpdate = DateTime.now();
  static const Duration _cacheTimeout = Duration(minutes: 5);

  /// Check if current user has admin privileges
  Future<bool> isAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return await hasRole(user.uid, UserRole.admin);
  }

  /// Check if current user has staff privileges
  Future<bool> isStaff() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    return await hasRole(user.uid, UserRole.staff);
  }

  /// Check if specific user has specific role
  Future<bool> hasRole(String userId, UserRole requiredRole) async {
    // Check cache first
    if (_roleCache.containsKey(userId) && 
        DateTime.now().difference(_lastCacheUpdate) < _cacheTimeout) {
      return _roleCache[userId] == requiredRole;
    }

    try {
      final snapshot = await _database.ref('users').child(userId).get();
      if (!snapshot.exists) return false;
      
      final userData = snapshot.value as Map<dynamic, dynamic>;
      final userRole = userData['role'] as String?;
      
      if (userRole == null) return false;
      
      final roleEnum = userRole == 'admin' ? UserRole.admin : UserRole.staff;
      
      // Update cache
      _roleCache[userId] = roleEnum;
      _lastCacheUpdate = DateTime.now();
      
      return roleEnum == requiredRole;
    } catch (e) {
      return false;
    }
  }

  /// Get current user role with caching
  Future<UserRole?> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    // Check cache first
    if (_roleCache.containsKey(user.uid) && 
        DateTime.now().difference(_lastCacheUpdate) < _cacheTimeout) {
      return _roleCache[user.uid];
    }

    try {
      final snapshot = await _database.ref('users').child(user.uid).get();
      if (!snapshot.exists) return null;
      
      final userData = snapshot.value as Map<dynamic, dynamic>;
      final role = userData['role'] as String?;
      
      if (role == null) return null;
      
      final userRole = role == 'admin' ? UserRole.admin : UserRole.staff;
      
      // Update cache
      _roleCache[user.uid] = userRole;
      _lastCacheUpdate = DateTime.now();
      
      return userRole;
    } catch (e) {
      return null;
    }
  }

  /// Check if user can access specific data
  Future<bool> canAccessData(String dataOwnerId, {bool adminOverride = true}) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return false;
    
    // Admin can access all data if adminOverride is true
    if (adminOverride && await isAdmin()) return true;
    
    // Users can only access their own data
    return currentUser.uid == dataOwnerId;
  }

  /// Validate user session
  Future<bool> isSessionValid() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    try {
      // Refresh token to check if session is still valid
      await user.getIdToken(true);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Force refresh user role cache
  void refreshRoleCache() {
    _roleCache.clear();
    _lastCacheUpdate = DateTime.now().subtract(Duration(hours: 1));
  }

  /// Get user permissions based on role
  Map<String, bool> getUserPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return {
          'create_tasks': true,
          'edit_tasks': true,
          'delete_tasks': true,
          'view_all_tasks': true,
          'manage_staff': true,
          'send_notifications': true,
          'view_audit_logs': true,
          'change_password': true,
          'view_reports': true,
          'manage_shifts': true,
        };
      case UserRole.staff:
        return {
          'create_tasks': false,
          'edit_tasks': true, // Can edit status of assigned tasks
          'delete_tasks': false,
          'view_all_tasks': false,
          'manage_staff': false,
          'send_notifications': false,
          'view_audit_logs': false,
          'change_password': true,
          'view_reports': false,
          'manage_shifts': false,
        };
    }
  }

  /// Check if current user has specific permission
  Future<bool> hasPermission(String permission) async {
    final role = await getCurrentUserRole();
    if (role == null) return false;
    
    final permissions = getUserPermissions(role);
    return permissions[permission] ?? false;
  }

  /// Clear role cache (useful for logout)
  void clearCache() {
    _roleCache.clear();
  }
}

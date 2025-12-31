class AuditLog {
  final String id;
  final String adminId;
  final String action;
  final DateTime timestamp;
  final Map<String, dynamic> details;

  AuditLog({
    required this.id,
    required this.adminId,
    required this.action,
    required this.timestamp,
    required this.details,
  });

  Map<String, dynamic> toMap() {
    return {
      'adminId': adminId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
    };
  }

  factory AuditLog.fromMap(String id, Map<dynamic, dynamic> map) {
    return AuditLog(
      id: id,
      adminId: map['adminId'] as String,
      action: map['action'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      details: Map<String, dynamic>.from(map['details'] as Map),
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool read;
  final String recipientUserId;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.read = false,
    required this.recipientUserId,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'recipientUserId': recipientUserId,
    };
  }

  static AppNotification fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      timestamp: map['timestamp'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : (map['timestamp'] != null && (map['timestamp'] as String).isNotEmpty
              ? DateTime.parse(map['timestamp'] as String)
              : DateTime.now()),
      read: map['read'] as bool? ?? false,
      recipientUserId: map['recipientUserId'] as String? ?? '',
    );
  }
}

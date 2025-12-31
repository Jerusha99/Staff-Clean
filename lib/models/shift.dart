class Shift {
  final String id;
  final String userId;
  final String userName;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? breakStartTime;
  final DateTime? breakEndTime;

  Shift({
    required this.id,
    required this.userId,
    required this.userName,
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'breakStartTime': breakStartTime?.toIso8601String(),
      'breakEndTime': breakEndTime?.toIso8601String(),
    };
  }

  static Shift fromMap(String id, Map<String, dynamic> map) {
    return Shift(
      id: id,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: DateTime.parse(map['endTime'] as String),
      breakStartTime: map['breakStartTime'] != null ? DateTime.parse(map['breakStartTime'] as String) : null,
      breakEndTime: map['breakEndTime'] != null ? DateTime.parse(map['breakEndTime'] as String) : null,
    );
  }
}

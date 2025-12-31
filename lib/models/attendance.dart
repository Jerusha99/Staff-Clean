class Attendance {
  final String id;
  final String userId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final DateTime date;

  Attendance({
    required this.id,
    required this.userId,
    required this.checkInTime,
    this.checkOutTime,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'date': date.toIso8601String(),
    };
  }

  static Attendance fromMap(String id, Map<String, dynamic> map) {
    return Attendance(
      id: id,
      userId: map['userId'] as String,
      checkInTime: DateTime.parse(map['checkInTime'] as String),
      checkOutTime: map['checkOutTime'] != null ? DateTime.parse(map['checkOutTime'] as String) : null,
      date: DateTime.parse(map['date'] as String),
    );
  }
}

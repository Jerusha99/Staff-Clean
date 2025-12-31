enum IssueStatus {
  reported,
  inProgress,
  resolved,
}

class Issue {
  final String id;
  final String userId;
  final String userName;
  final String issueType;
  final String description;
  final DateTime timestamp;
  final IssueStatus status;

  Issue({
    required this.id,
    required this.userId,
    required this.userName,
    required this.issueType,
    required this.description,
    required this.timestamp,
    this.status = IssueStatus.reported,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'issueType': issueType,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
    };
  }

  static Issue fromMap(String id, Map<String, dynamic> map) {
    return Issue(
      id: id,
      userId: map['userId'] as String,
      userName: map['userName'] as String,
      issueType: map['issueType'] as String,
      description: map['description'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: IssueStatus.values.firstWhere((e) => e.name == map['status']),
    );
  }
}

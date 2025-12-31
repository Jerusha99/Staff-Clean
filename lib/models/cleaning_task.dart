enum CleaningStatus { pending, inProgress, completed }

enum CleaningArea {
  lectureHalls,
  computerLabs,
  washrooms,
  libraryStudyAreas,
  cafeteria,
  corridorsStairsElevators,
  outdoorAreas,
  storerooms,
  labs,
  carpets,
  externalWalls,
}

enum CleaningFrequency { daily, weekly, monthly, quarterly, annually }

class CleaningTask {
  final String id;
  final String title;
  final String description;
  final CleaningArea area;
  final String assignedTo;
  final String assignedToName;
  final DateTime dueDate;
  final CleaningFrequency frequency;
  final DateTime? lastCleanedDate;
  final CleaningStatus status;
  final String? proofOfWorkUrl;
  final String creatorUid; // New field
  final String creatorName; // New field

  CleaningTask({
    required this.id,
    required this.title,
    required this.description,
    required this.area,
    required this.assignedTo,
    required this.assignedToName,
    required this.dueDate,
    required this.frequency,
    this.lastCleanedDate,
    this.status = CleaningStatus.pending,
    this.proofOfWorkUrl,
    required this.creatorUid, // New field
    required this.creatorName, // New field
  });

  factory CleaningTask.fromMap(String id, Map<dynamic, dynamic> data) {
    // Helper function for safe enum parsing
        T parseEnum<T>(List<T> values, String? value, T defaultValue) {
      if (value == null) return defaultValue;
      for (var v in values) {
        if (v.toString().split('.').last == value) {
          return v;
        }
      }
      return defaultValue;
    }

    // Helper function for safe date parsing
        DateTime? parseDate(dynamic value) {
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return null;
    }

    return CleaningTask(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      area: parseEnum(CleaningArea.values, data['area'] as String?, CleaningArea.storerooms),
      assignedTo: data['assignedTo'] as String? ?? '',
      assignedToName: data['assignedToName'] as String? ?? '',
      dueDate: parseDate(data['dueDate']) ?? DateTime.now(),
      frequency: parseEnum(CleaningFrequency.values, data['frequency'] as String?, CleaningFrequency.weekly),
      lastCleanedDate: parseDate(data['lastCleanedDate']),
      status: parseEnum(CleaningStatus.values, data['status'] as String?, CleaningStatus.pending),
      proofOfWorkUrl: data['proofOfWorkUrl'] as String?,
      creatorUid: data['creatorUid'] as String? ?? '',
      creatorName: data['creatorName'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'area': area.toString().split('.').last,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'frequency': frequency.toString().split('.').last,
      'lastCleanedDate': lastCleanedDate?.millisecondsSinceEpoch,
      'status': status.toString().split('.').last,
      'proofOfWorkUrl': proofOfWorkUrl,
      'creatorUid': creatorUid, // New field
      'creatorName': creatorName, // New field
    };
  }
}


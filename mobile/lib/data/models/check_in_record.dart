/// M1 Structured Check-in Data Model.
class CheckInRecord {
  final String id;
  final String userId;
  final DateTime timestamp;
  final String sessionType; // MORNING, EVENING, ADHOC
  final int perceivedStress; // 1 to 5
  final int moodValence; // 1 to 5
  final int moodArousal; // 1 to 5
  final int? motivationLevel; // 1 to 5
  final double completionLatencySec;

  CheckInRecord({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.sessionType,
    required this.perceivedStress,
    required this.moodValence,
    required this.moodArousal,
    this.motivationLevel,
    required this.completionLatencySec,
  });

  Map<String, dynamic> toMap() {
    return {
      'check_in_id': id,
      'user_id': userId,
      'timestamp_utc': timestamp.toUtc().toIso8601String(),
      'session_type': sessionType,
      'perceived_stress': perceivedStress,
      'mood_valence': moodValence,
      'mood_arousal': moodArousal,
      'motivation_level': motivationLevel,
      'completion_latency_sec': completionLatencySec,
    };
  }

  factory CheckInRecord.fromMap(Map<String, dynamic> map) {
    return CheckInRecord(
      id: map['check_in_id'] as String,
      userId: map['user_id'] as String,
      timestamp: DateTime.parse(map['timestamp_utc'] as String),
      sessionType: map['session_type'] as String,
      perceivedStress: map['perceived_stress'] as int,
      moodValence: map['mood_valence'] as int,
      moodArousal: map['mood_arousal'] as int,
      motivationLevel: map['motivation_level'] as int?,
      completionLatencySec: (map['completion_latency_sec'] as num).toDouble(),
    );
  }
}


/// M3 Sleep Tracking Data Model.
class SleepRecord {
  final String id;
  final String userId;
  final String dateEpoch; // YYYY-MM-DD
  final DateTime bedtime;
  final DateTime wakeTime;
  final int totalSleepMinutes;
  final int? sleepQualityRating; // 1 to 5
  final String sourceType; // MANUAL_LOG, HEALTH_CONNECT, HEALTHKIT

  SleepRecord({
    required this.id,
    required this.userId,
    required this.dateEpoch,
    required this.bedtime,
    required this.wakeTime,
    required this.totalSleepMinutes,
    this.sleepQualityRating,
    this.sourceType = 'MANUAL_LOG',
  });

  double get totalSleepHours => totalSleepMinutes / 60.0;

  Map<String, dynamic> toMap() {
    return {
      'sleep_id': id,
      'user_id': userId,
      'date_epoch': dateEpoch,
      'bedtime_utc': bedtime.toUtc().toIso8601String(),
      'wake_time_utc': wakeTime.toUtc().toIso8601String(),
      'total_sleep_minutes': totalSleepMinutes,
      'sleep_quality_rating': sleepQualityRating,
      'source_type': sourceType,
    };
  }

  factory SleepRecord.fromMap(Map<String, dynamic> map) {
    return SleepRecord(
      id: map['sleep_id'] as String,
      userId: map['user_id'] as String,
      dateEpoch: map['date_epoch'] as String,
      bedtime: DateTime.parse(map['bedtime_utc'] as String),
      wakeTime: DateTime.parse(map['wake_time_utc'] as String),
      totalSleepMinutes: map['total_sleep_minutes'] as int,
      sleepQualityRating: map['sleep_quality_rating'] as int?,
      sourceType: map['source_type'] as String? ?? 'MANUAL_LOG',
    );
  }
}


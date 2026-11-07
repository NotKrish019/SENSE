/// User Baseline and Calibration State Data Model.
class UserBaselineRecord {
  final String id;
  final String userId;
  final String dateEpoch;
  final int calibrationDayCount;
  final bool isCalibrated;
  final double? sleepMeanHours;
  final double? sleepStdHours;
  final double? stressMeanRating;
  final double? stressStdRating;
  final double? workloadMeanRating;
  final double? workloadStdRating;

  UserBaselineRecord({
    required this.id,
    required this.userId,
    required this.dateEpoch,
    required this.calibrationDayCount,
    required this.isCalibrated,
    this.sleepMeanHours,
    this.sleepStdHours,
    this.stressMeanRating,
    this.stressStdRating,
    this.workloadMeanRating,
    this.workloadStdRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'baseline_id': id,
      'user_id': userId,
      'date_epoch': dateEpoch,
      'calibration_day_count': calibrationDayCount,
      'is_calibrated': isCalibrated ? 1 : 0,
      'sleep_mean_hours': sleepMeanHours,
      'sleep_std_hours': sleepStdHours,
      'stress_mean_rating': stressMeanRating,
      'stress_std_rating': stressStdRating,
      'workload_mean_rating': workloadMeanRating,
      'workload_std_rating': workloadStdRating,
    };
  }

  factory UserBaselineRecord.fromMap(Map<String, dynamic> map) {
    return UserBaselineRecord(
      id: map['baseline_id'] as String,
      userId: map['user_id'] as String,
      dateEpoch: map['date_epoch'] as String,
      calibrationDayCount: map['calibration_day_count'] as int,
      isCalibrated: (map['is_calibrated'] as int) == 1,
      sleepMeanHours: (map['sleep_mean_hours'] as num?)?.toDouble(),
      sleepStdHours: (map['sleep_std_hours'] as num?)?.toDouble(),
      stressMeanRating: (map['stress_mean_rating'] as num?)?.toDouble(),
      stressStdRating: (map['stress_std_rating'] as num?)?.toDouble(),
      workloadMeanRating: (map['workload_mean_rating'] as num?)?.toDouble(),
      workloadStdRating: (map['workload_std_rating'] as num?)?.toDouble(),
    );
  }
}


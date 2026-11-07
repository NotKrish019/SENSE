/// M4 Cognitive Workload Data Model.
class WorkloadRecord {
  final String id;
  final String userId;
  final String dateEpoch; // YYYY-MM-DD
  final int mentalDemandRating; // 1 to 5 (NASA-TLX subscale)
  final int effortRating; // 1 to 5
  final int? tasksCompletedCount;
  final int? impendingDeadlinesCount;

  WorkloadRecord({
    required this.id,
    required this.userId,
    required this.dateEpoch,
    required this.mentalDemandRating,
    required this.effortRating,
    this.tasksCompletedCount,
    this.impendingDeadlinesCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'workload_id': id,
      'user_id': userId,
      'date_epoch': dateEpoch,
      'mental_demand_rating': mentalDemandRating,
      'effort_rating': effortRating,
      'tasks_completed_count': tasksCompletedCount,
      'impending_deadlines_count': impendingDeadlinesCount,
    };
  }

  factory WorkloadRecord.fromMap(Map<String, dynamic> map) {
    return WorkloadRecord(
      id: map['workload_id'] as String,
      userId: map['user_id'] as String,
      dateEpoch: map['date_epoch'] as String,
      mentalDemandRating: map['mental_demand_rating'] as int,
      effortRating: map['effort_rating'] as int,
      tasksCompletedCount: map['tasks_completed_count'] as int?,
      impendingDeadlinesCount: map['impending_deadlines_count'] as int?,
    );
  }
}


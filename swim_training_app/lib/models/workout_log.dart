class WorkoutLog {
  final String id;
  final String programTitle;
  final String levelLabel;
  final String trainingGoal;
  final DateTime startedAt;
  final DateTime completedAt;
  final int plannedDistance; // 계획된 총 거리
  final int completedDistance; // 실제 완료 거리
  final List<SetLog> sets;

  WorkoutLog({
    required this.id,
    required this.programTitle,
    required this.levelLabel,
    required this.trainingGoal,
    required this.startedAt,
    required this.completedAt,
    required this.plannedDistance,
    required this.completedDistance,
    required this.sets,
  });

  double get completionRate =>
      plannedDistance > 0 ? (completedDistance / plannedDistance * 100) : 0;

  int get durationMinutes =>
      completedAt.difference(startedAt).inMinutes;

  Map<String, dynamic> toJson() => {
    'id': id,
    'program_title': programTitle,
    'level_label': levelLabel,
    'training_goal': trainingGoal,
    'started_at': startedAt.toIso8601String(),
    'completed_at': completedAt.toIso8601String(),
    'planned_distance': plannedDistance,
    'completed_distance': completedDistance,
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    programTitle: json['program_title'] as String,
    levelLabel: json['level_label'] as String,
    trainingGoal: json['training_goal'] as String,
    startedAt: DateTime.parse(json['started_at'] as String),
    completedAt: DateTime.parse(json['completed_at'] as String),
    plannedDistance: json['planned_distance'] as int,
    completedDistance: json['completed_distance'] as int,
    sets: (json['sets'] as List)
        .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

class SetLog {
  final String exercise; // 운동 설명
  final int distance; // 거리
  final int repeat; // 반복
  final String status; // completed, skipped, paused
  final int? durationSeconds; // 소요 시간
  final List<PauseLog> pauses; // 정지 기록

  SetLog({
    required this.exercise,
    required this.distance,
    required this.repeat,
    required this.status,
    this.durationSeconds,
    this.pauses = const [],
  });

  int get totalDistance => distance * repeat;

  Map<String, dynamic> toJson() => {
    'exercise': exercise,
    'distance': distance,
    'repeat': repeat,
    'status': status,
    if (durationSeconds != null) 'duration_seconds': durationSeconds,
    'pauses': pauses.map((p) => p.toJson()).toList(),
  };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
    exercise: json['exercise'] as String,
    distance: json['distance'] as int,
    repeat: json['repeat'] as int,
    status: json['status'] as String,
    durationSeconds: json['duration_seconds'] as int?,
    pauses: json['pauses'] != null
        ? (json['pauses'] as List)
            .map((p) => PauseLog.fromJson(p as Map<String, dynamic>))
            .toList()
        : [],
  );
}

class PauseLog {
  final DateTime pausedAt;
  final int durationSeconds;

  PauseLog({
    required this.pausedAt,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
    'paused_at': pausedAt.toIso8601String(),
    'duration_seconds': durationSeconds,
  };

  factory PauseLog.fromJson(Map<String, dynamic> json) => PauseLog(
    pausedAt: DateTime.parse(json['paused_at'] as String),
    durationSeconds: json['duration_seconds'] as int,
  );
}

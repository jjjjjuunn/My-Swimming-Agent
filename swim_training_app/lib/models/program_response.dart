class ProgramResponse {
  final String trainingGoal;
  final List<String> strokes;
  final ProgramLevel beginner;
  final ProgramLevel intermediate;
  final ProgramLevel advanced;

  ProgramResponse({
    required this.trainingGoal,
    required this.strokes,
    required this.beginner,
    required this.intermediate,
    required this.advanced,
  });

  factory ProgramResponse.fromJson(Map<String, dynamic> json) {
    return ProgramResponse(
      trainingGoal: json['training_goal'] as String,
      strokes: List<String>.from(json['strokes'] as List),
      beginner: ProgramLevel.fromJson(json['beginner'] as Map<String, dynamic>),
      intermediate: ProgramLevel.fromJson(json['intermediate'] as Map<String, dynamic>),
      advanced: ProgramLevel.fromJson(json['advanced'] as Map<String, dynamic>),
    );
  }
}

class ProgramLevel {
  final String level;
  final String levelLabel;
  final String description;
  final List<Exercise> warmup;
  final List<Exercise> mainSet;
  final List<Exercise> cooldown;
  final int totalDistance;
  final int estimatedMinutes;

  ProgramLevel({
    required this.level,
    required this.levelLabel,
    required this.description,
    required this.warmup,
    required this.mainSet,
    required this.cooldown,
    required this.totalDistance,
    required this.estimatedMinutes,
  });

  factory ProgramLevel.fromJson(Map<String, dynamic> json) {
    return ProgramLevel(
      level: json['level'] as String,
      levelLabel: json['level_label'] as String,
      description: json['description'] as String,
      warmup: (json['warmup'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      mainSet: (json['main_set'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      cooldown: (json['cooldown'] as List)
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalDistance: json['total_distance'] as int,
      estimatedMinutes: json['estimated_minutes'] as int,
    );
  }

  ProgramLevel copyWith({
    String? level,
    String? levelLabel,
    String? description,
    List<Exercise>? warmup,
    List<Exercise>? mainSet,
    List<Exercise>? cooldown,
    int? totalDistance,
    int? estimatedMinutes,
  }) {
    return ProgramLevel(
      level: level ?? this.level,
      levelLabel: levelLabel ?? this.levelLabel,
      description: description ?? this.description,
      warmup: warmup ?? this.warmup,
      mainSet: mainSet ?? this.mainSet,
      cooldown: cooldown ?? this.cooldown,
      totalDistance: totalDistance ?? this.totalDistance,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  /// 운동 목록에서 총 거리를 재계산
  ProgramLevel recalculate() {
    int total = 0;
    for (final e in warmup) total += e.totalDistance;
    for (final e in mainSet) total += e.totalDistance;
    for (final e in cooldown) total += e.totalDistance;
    return copyWith(totalDistance: total);
  }
}

class Exercise {
  final String description;
  final int distance;
  final int repeat;
  final int restSeconds;
  final String notes;
  final String? cycleTime; // e.g. "2:15" — 사이클 타임 (인터벌)

  Exercise({
    required this.description,
    required this.distance,
    required this.repeat,
    required this.restSeconds,
    required this.notes,
    this.cycleTime,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      description: json['description'] as String,
      distance: json['distance'] as int,
      repeat: json['repeat'] as int,
      restSeconds: json['rest_seconds'] as int,
      notes: json['notes'] as String,
      cycleTime: json['cycle_time'] as String?,
    );
  }

  int get totalDistance => distance * repeat;

  Exercise copyWith({
    String? description,
    int? distance,
    int? repeat,
    int? restSeconds,
    String? notes,
    String? cycleTime,
  }) {
    return Exercise(
      description: description ?? this.description,
      distance: distance ?? this.distance,
      repeat: repeat ?? this.repeat,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      cycleTime: cycleTime ?? this.cycleTime,
    );
  }
}

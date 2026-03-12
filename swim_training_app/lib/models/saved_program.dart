import 'program_response.dart';

class SavedProgram {
  final String id; // 고유 ID
  final String title; // 사용자 지정 제목
  final ProgramLevel program;
  final ProgramLevel? originalProgram; // 최초 원본 (수정 전)
  final String levelLabel; // 초급/중급/고급
  final DateTime savedAt;
  final String? memo; // 사용자 메모
  final String trainingGoal; // speed, endurance, etc.
  final List<String> strokes; // 종목
  final List<String>? equipment; // 사용한 도구

  SavedProgram({
    required this.id,
    required this.title,
    required this.program,
    this.originalProgram,
    required this.levelLabel,
    required this.savedAt,
    this.memo,
    required this.trainingGoal,
    required this.strokes,
    this.equipment,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'program': {
        'level': program.level,
        'level_label': program.levelLabel,
        'description': program.description,
        'warmup': program.warmup.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'main_set': program.mainSet.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'cooldown': program.cooldown.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'total_distance': program.totalDistance,
        'estimated_minutes': program.estimatedMinutes,
      },
      'original_program': originalProgram != null ? {
        'level': originalProgram!.level,
        'level_label': originalProgram!.levelLabel,
        'description': originalProgram!.description,
        'warmup': originalProgram!.warmup.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'main_set': originalProgram!.mainSet.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'cooldown': originalProgram!.cooldown.map((e) => {
          'description': e.description,
          'distance': e.distance,
          'repeat': e.repeat,
          'rest_seconds': e.restSeconds,
          'notes': e.notes,
          if (e.cycleTime != null) 'cycle_time': e.cycleTime,
        }).toList(),
        'total_distance': originalProgram!.totalDistance,
        'estimated_minutes': originalProgram!.estimatedMinutes,
      } : null,
      'level_label': levelLabel,
      'saved_at': savedAt.toIso8601String(),
      'memo': memo,
      'training_goal': trainingGoal,
      'strokes': strokes,
      if (equipment != null) 'equipment': equipment,
    };
  }

  factory SavedProgram.fromJson(Map<String, dynamic> json) {
    return SavedProgram(
      id: json['id'] as String,
      title: json['title'] as String,
      program: ProgramLevel.fromJson(json['program'] as Map<String, dynamic>),
      originalProgram: json['original_program'] != null
          ? ProgramLevel.fromJson(json['original_program'] as Map<String, dynamic>)
          : null,
      levelLabel: json['level_label'] as String,
      savedAt: DateTime.parse(json['saved_at'] as String),
      memo: json['memo'] as String?,
      trainingGoal: json['training_goal'] as String,
      strokes: List<String>.from(json['strokes'] as List),
      equipment: json['equipment'] != null
          ? List<String>.from(json['equipment'] as List)
          : null,
    );
  }

  // 복사본 생성 (편집용)
  SavedProgram copyWith({
    String? title,
    ProgramLevel? program,
    ProgramLevel? originalProgram,
    String? memo,
  }) {
    return SavedProgram(
      id: id,
      title: title ?? this.title,
      program: program ?? this.program,
      originalProgram: originalProgram ?? this.originalProgram,
      levelLabel: levelLabel,
      savedAt: savedAt,
      memo: memo ?? this.memo,
      trainingGoal: trainingGoal,
      strokes: strokes,
      equipment: equipment,
    );
  }
}

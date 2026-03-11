class ProgramRequest {
  final String trainingGoal;
  final List<String> strokes;
  final List<String>? equipment;
  final String? userId;
  final String? purpose;

  ProgramRequest({
    required this.trainingGoal,
    required this.strokes,
    this.equipment,
    this.userId,
    this.purpose,
  });

  Map<String, dynamic> toJson() {
    return {
      'training_goal': trainingGoal,
      'strokes': strokes,
      if (equipment != null && equipment!.isNotEmpty) 'equipment': equipment,
      if (userId != null) 'user_id': userId,
      if (purpose != null) 'purpose': purpose,
    };
  }
}

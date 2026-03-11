class UserModel {
  final String uid;
  final String email;
  final String? displayName;
  final String? nickname; // 커뮤니티용 닉네임
  final DateTime? lastNicknameChange; // 마지막 닉네임 변경일
  final String? photoURL;
  final DateTime createdAt;
  final DateTime lastLogin;
  
  // 사용자 수영 정보
  final String? level; // beginner, intermediate, advanced, elite
  final String? purpose; // competition, hobby, fitness, diet
  final List<String> favoriteStrokes; // 선호하는 영법
  final List<String> goals; // 목표들
  final Map<String, dynamic> personalRecords; // 개인 기록
  
  // 온보딩
  final bool onboardingCompleted;
  final DateTime? onboardingCompletedAt;

  UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.nickname,
    this.lastNicknameChange,
    this.photoURL,
    required this.createdAt,
    required this.lastLogin,
    this.level,
    this.purpose,
    this.favoriteStrokes = const [],
    this.goals = const [],
    this.personalRecords = const {},
    this.onboardingCompleted = false,
    this.onboardingCompletedAt,
  });

  // 닉네임 변경 가능 여부 (4주 제한)
  bool get canChangeNickname {
    if (lastNicknameChange == null) return true;
    final daysSinceChange = DateTime.now().difference(lastNicknameChange!).inDays;
    return daysSinceChange >= 28; // 4주 = 28일
  }

  // 다음 닉네임 변경 가능일
  DateTime? get nextNicknameChangeDate {
    if (lastNicknameChange == null) return null;
    return lastNicknameChange!.add(const Duration(days: 28));
  }

  // 남은 일수
  int get daysUntilNicknameChange {
    if (canChangeNickname) return 0;
    return 28 - DateTime.now().difference(lastNicknameChange!).inDays;
  }

  // Firestore에서 가져오기
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'],
      nickname: map['nickname'],
      lastNicknameChange: map['lastNicknameChange'] != null 
          ? DateTime.parse(map['lastNicknameChange']) 
          : null,
      photoURL: map['photoURL'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastLogin: DateTime.parse(map['lastLogin'] ?? DateTime.now().toIso8601String()),
      level: map['level'],
      purpose: map['purpose'],
      favoriteStrokes: List<String>.from(map['favoriteStrokes'] ?? []),
      goals: List<String>.from(map['goals'] ?? []),
      personalRecords: Map<String, dynamic>.from(map['personalRecords'] ?? {}),
      onboardingCompleted: map['onboardingCompleted'] ?? false,
      onboardingCompletedAt: map['onboardingCompletedAt'] != null
          ? DateTime.parse(map['onboardingCompletedAt'])
          : null,
    );
  }

  // Firestore에 저장하기
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'nickname': nickname,
      'lastNicknameChange': lastNicknameChange?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'level': level,
      'purpose': purpose,
      'favoriteStrokes': favoriteStrokes,
      'goals': goals,
      'personalRecords': personalRecords,
      'onboardingCompleted': onboardingCompleted,
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
    };
  }

  // 복사본 생성 (업데이트용)
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? nickname,
    DateTime? lastNicknameChange,
    String? photoURL,
    DateTime? createdAt,
    DateTime? lastLogin,
    String? level,
    String? purpose,
    List<String>? favoriteStrokes,
    List<String>? goals,
    Map<String, dynamic>? personalRecords,
    bool? onboardingCompleted,
    DateTime? onboardingCompletedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nickname: nickname ?? this.nickname,
      lastNicknameChange: lastNicknameChange ?? this.lastNicknameChange,
      photoURL: photoURL ?? this.photoURL,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      level: level ?? this.level,
      purpose: purpose ?? this.purpose,
      favoriteStrokes: favoriteStrokes ?? this.favoriteStrokes,
      goals: goals ?? this.goals,
      personalRecords: personalRecords ?? this.personalRecords,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
    );
  }
}

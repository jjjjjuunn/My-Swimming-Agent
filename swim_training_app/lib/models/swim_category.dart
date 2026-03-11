class SwimCategory {
  final String id;
  final String name;
  final String icon;
  final List<SwimTechnique> techniques;

  SwimCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.techniques,
  });
}

class SwimTechnique {
  final String id;
  final String name;
  final List<String> subTopics;

  SwimTechnique({
    required this.id,
    required this.name,
    required this.subTopics,
  });
}

// 수영 카테고리 데이터
final List<SwimCategory> swimCategories = [
  SwimCategory(
    id: 'freestyle',
    name: '자유형 (Freestyle)',
    icon: '🏊‍♂️',
    techniques: [
      SwimTechnique(
        id: 'freestyle_breathing',
        name: '호흡',
        subTopics: [
          '호흡 타이밍',
          '양측 호흡',
          '호흡 각도',
          '수중 날숨',
        ],
      ),
      SwimTechnique(
        id: 'freestyle_kick',
        name: '킥',
        subTopics: [
          '플러터 킥',
          '킥 타이밍',
          '발목 유연성',
          '킥 드릴',
        ],
      ),
      SwimTechnique(
        id: 'freestyle_stroke',
        name: '팔 동작',
        subTopics: [
          '입수',
          '캐치',
          '풀',
          '리커버리',
          '하이 엘보우',
        ],
      ),
    ],
  ),
  SwimCategory(
    id: 'butterfly',
    name: '접영 (Butterfly)',
    icon: '🦋',
    techniques: [
      SwimTechnique(
        id: 'butterfly_dolphin_kick',
        name: '돌핀킥',
        subTopics: [
          '돌핀킥 기초',
          '타이밍',
          '파동 동작',
          '수중 돌핀킥',
        ],
      ),
      SwimTechnique(
        id: 'butterfly_breathing',
        name: '호흡',
        subTopics: [
          '호흡 타이밍',
          '머리 움직임',
          '호흡 빈도',
        ],
      ),
      SwimTechnique(
        id: 'butterfly_stroke',
        name: '팔 동작',
        subTopics: [
          '키홀 패턴',
          '입수',
          '풀',
          '리커버리',
        ],
      ),
      SwimTechnique(
        id: 'butterfly_drills',
        name: '드릴/연습법',
        subTopics: [
          '원암 접영',
          '3-3-3 드릴',
          '돌핀킥 연습',
        ],
      ),
    ],
  ),
  SwimCategory(
    id: 'backstroke',
    name: '배영 (Backstroke)',
    icon: '🏊',
    techniques: [
      SwimTechnique(
        id: 'backstroke_kick',
        name: '킥',
        subTopics: [
          '플러터 킥',
          '킥 타이밍',
          '무릎 각도',
        ],
      ),
      SwimTechnique(
        id: 'backstroke_stroke',
        name: '팔 동작',
        subTopics: [
          '입수',
          '캐치',
          '풀',
          '리커버리',
        ],
      ),
      SwimTechnique(
        id: 'backstroke_body',
        name: '바디 포지션',
        subTopics: [
          '몸 회전',
          '머리 위치',
          '스트레이트 라인',
        ],
      ),
    ],
  ),
  SwimCategory(
    id: 'breaststroke',
    name: '평영 (Breaststroke)',
    icon: '🐸',
    techniques: [
      SwimTechnique(
        id: 'breaststroke_kick',
        name: '킥',
        subTopics: [
          '웨지 킥',
          '휩 킥',
          '킥 타이밍',
          '발목 회전',
        ],
      ),
      SwimTechnique(
        id: 'breaststroke_pull',
        name: '풀',
        subTopics: [
          '아웃스윕',
          '인스윕',
          '글라이드',
        ],
      ),
      SwimTechnique(
        id: 'breaststroke_timing',
        name: '타이밍',
        subTopics: [
          '풀-킥 타이밍',
          '호흡 타이밍',
          '글라이드 시간',
        ],
      ),
    ],
  ),
];

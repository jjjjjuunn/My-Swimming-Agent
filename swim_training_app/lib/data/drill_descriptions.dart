class DrillInfo {
  final String name;
  final String purpose;
  final String method;
  final String effect;
  final String stroke;

  const DrillInfo({
    required this.name,
    required this.purpose,
    required this.method,
    required this.effect,
    required this.stroke,
  });
}

/// exercise.description에서 드릴 정보를 찾는 헬퍼
DrillInfo? findDrillInfo(String description) {
  for (final entry in drillDescriptions.entries) {
    if (description.contains(entry.key)) {
      return entry.value;
    }
  }
  return null;
}

const Map<String, DrillInfo> drillDescriptions = {
  // ── 자유형 (Freestyle) ──────────────────────────────
  '캐치업': DrillInfo(
    name: '캐치업 드릴',
    purpose: '팔 진입 타이밍과 글라이드 감각 훈련',
    method: '한 팔이 앞으로 뻗어있는 동안 다른 팔이 당기기를 완료한 후, 앞에서 두 손이 만나면 다음 스트로크를 시작합니다.',
    effect: '스트로크 균형 향상, 글라이드 효율 극대화, 조급한 입수 습관 교정',
    stroke: '자유형',
  ),
  '핑거팁 드래그': DrillInfo(
    name: '핑거팁 드래그 드릴',
    purpose: '높은 팔꿈치 회복(High-Elbow Recovery) 훈련',
    method: '팔 회복 시 손가락 끝이 수면을 스치듯 끌면서 앞으로 가져옵니다. 팔꿈치가 자연스럽게 높아집니다.',
    effect: '회복 팔의 높은 팔꿈치 유도, 어깨 부담 감소, 부드러운 입수',
    stroke: '자유형',
  ),
  '6킥 1스트로크': DrillInfo(
    name: '6킥 1스트로크 드릴',
    purpose: '균형과 킥 타이밍 훈련',
    method: '한 사이클(한 팔 당기기) 당 6회 킥을 실시합니다. 옆으로 눕는 자세를 유지하며 킥합니다.',
    effect: '보디 로테이션 감각, 킥과 스트로크의 타이밍 일치, 수평 자세 유지',
    stroke: '자유형',
  ),
  '편팔': DrillInfo(
    name: '프리스타일 편팔(SKMO) 드릴',
    purpose: '대칭 스트로크 교정',
    method: '한쪽 팔만 사용하여 수영합니다. 사용하지 않는 팔은 몸 옆에 붙이거나 앞으로 뻗습니다.',
    effect: '좌우 스트로크 비대칭 교정, 약한 쪽 팔 강화, 회전각 인식',
    stroke: '자유형',
  ),
  '지퍼': DrillInfo(
    name: '지퍼 드릴',
    purpose: '높은 팔꿈치 회복 유도',
    method: '회복팔의 엄지가 옆구리의 지퍼를 올리듯 몸통을 따라 위로 끌어올립니다.',
    effect: '팔꿈치가 자연스럽게 높아져 효율적인 팔 회복, 입수 각도 개선',
    stroke: '자유형',
  ),
  '사이드킥 드릴': DrillInfo(
    name: '사이드킥 드릴',
    purpose: '보디 로테이션각 훈련',
    method: '옆으로 누운 자세에서 킥만 실시합니다. 아래쪽 팔은 앞으로 뻗고, 위쪽 팔은 몸 옆에 붙입니다.',
    effect: '수평 자세 유지, 올바른 회전각 감각, 킥 효율 향상',
    stroke: '자유형',
  ),
  '프런트 스컬링': DrillInfo(
    name: '프런트 스컬링',
    purpose: '손목·전완 catch 감각 훈련',
    method: '팔을 앞으로 뻗은 상태에서 손바닥을 안-밖으로 작게 움직여 전진합니다.',
    effect: 'catch 초기 구간의 물 잡는 감각 향상, 전완 근력 강화',
    stroke: '자유형',
  ),
  '피스트 스윔': DrillInfo(
    name: '피스트 스윔',
    purpose: '전완 압력 감각 훈련',
    method: '주먹을 쥔 상태로 수영합니다. 일정 거리 후 손을 펼쳐 수영합니다.',
    effect: '전완으로 물 잡는 감각 극대화, 손을 폈을 때 catch 면적 인식 향상',
    stroke: '자유형',
  ),
  '네거티브 스플릿': DrillInfo(
    name: '네거티브 스플릿',
    purpose: '페이스 판단력 훈련',
    method: '후반 50%를 전반보다 빠르게 수영합니다. 예: 100m에서 전반 50m을 편하게, 후반 50m을 빠르게.',
    effect: '체력 분배 능력 향상, 레이스 전략 훈련, 심리적 자신감',
    stroke: '자유형',
  ),
  '양측 호흡': DrillInfo(
    name: '양측 호흡 드릴',
    purpose: '좌우 대칭·균형 훈련',
    method: '3스트로크마다 좌우 교대로 호흡합니다. USA Swimming 기본 드릴입니다.',
    effect: '좌우 스트로크 대칭, 보디 롤 균형, 한쪽 편향 교정',
    stroke: '자유형',
  ),
  'DPS 카운트': DrillInfo(
    name: 'DPS 카운트 수영',
    purpose: '추진 효율 극대화',
    method: '한 레인(25m)당 스트로크 수를 세며 수영합니다. 목표 횟수 이하로 줄이는 것이 목표입니다.',
    effect: '스트로크당 이동 거리(DPS) 향상, 물 저항 감소, 효율적 수영',
    stroke: '자유형',
  ),

  // ── 접영 (Butterfly) ──────────────────────────────
  '접영 원암': DrillInfo(
    name: '접영 원암(One-Arm) 드릴',
    purpose: '킥 타이밍 집중 훈련',
    method: '한 팔만 당기며 수영합니다. 사용하지 않는 팔은 앞으로 뻗거나 몸 옆에 붙입니다.',
    effect: '입수 킥과 출수 킥의 타이밍 인식, 비대칭 교정',
    stroke: '접영',
  ),
  '3-3-3 접영': DrillInfo(
    name: '3-3-3 접영 드릴',
    purpose: '비대칭 교정',
    method: '오른팔 3회 → 왼팔 3회 → 양팔 3회를 순환합니다.',
    effect: '좌우 팔 균형 발달, 접영 타이밍 안정화',
    stroke: '접영',
  ),
  '언더워터 돌핀킥': DrillInfo(
    name: '언더워터 돌핀킥',
    purpose: '수중 추진력·유선형 훈련',
    method: '수면 아래에서 스트림라인 자세를 유지하며 돌핀킥만으로 전진합니다.',
    effect: '킥 파워 향상, 유선형 자세 유지, 턴/출발 후 수중 구간 효율 극대화',
    stroke: '접영',
  ),
  '사이드 돌핀킥': DrillInfo(
    name: '사이드 돌핀킥',
    purpose: '무릎 굽힘 최소화 훈련',
    method: '옆으로 누운 자세에서 돌핀킥을 실시합니다.',
    effect: '무릎 과굽힘 교정, 고관절 중심의 킥 패턴 습득',
    stroke: '접영',
  ),
  '접영 바디 웨이브': DrillInfo(
    name: '접영 바디 웨이브 드릴',
    purpose: '몸통 유연성·타이밍 훈련',
    method: '킥 없이 파동 움직임만으로 전진합니다. 가슴 → 골반 → 다리 순서로 웨이브.',
    effect: '유연한 몸통 파동 습득, 접영 리듬감 향상',
    stroke: '접영',
  ),
  '접영 타이밍': DrillInfo(
    name: '접영 타이밍 드릴(2킥 1풀)',
    purpose: '입수 킥→당기기→출수 킥 타이밍 명확화',
    method: '한 사이클에 2회 킥: 입수 시 1킥, 출수 시 1킥을 의식적으로 분리합니다.',
    effect: '접영 킥-풀 타이밍 정확도 향상, 추진력 연결',
    stroke: '접영',
  ),
  '핀 돌핀킥': DrillInfo(
    name: '핀 돌핀킥',
    purpose: '파워·속도 감각 훈련',
    method: '오리발을 착용하고 수중 돌핀킥을 실시합니다.',
    effect: '킥 파워와 속도 감각 향상, 유산소 부하 증가',
    stroke: '접영',
  ),
  '언더워터 풀아웃': DrillInfo(
    name: '언더워터 풀아웃 드릴',
    purpose: '출발·턴 후 수중 구간 집중 훈련',
    method: '출발·턴 후 스트림라인 → 첫 풀다운 → 킥 타이밍을 15m 구간에서 반복 연습합니다.',
    effect: '출발/턴 후 효율적인 수중 동작, 레이스 전환 구간 최적화',
    stroke: '접영',
  ),

  // ── 배영 (Backstroke) ──────────────────────────────
  '배영 편팔': DrillInfo(
    name: '배영 편팔 드릴',
    purpose: '대칭·회전각 훈련',
    method: '한 팔씩 스트로크를 실시합니다. 사용하지 않는 팔은 몸 옆에 붙입니다.',
    effect: '좌우 스트로크 균형, 보디 로테이션 감각 향상',
    stroke: '배영',
  ),
  '6킥 스위치': DrillInfo(
    name: '6킥 스위치(6-Kick Switch) 드릴',
    purpose: '몸통 회전 타이밍 훈련',
    method: '6회 킥 후 스트로크를 전환합니다. 옆으로 누운 자세를 유지하며 킥합니다.',
    effect: '보디 롤 타이밍과 킥의 연동, 안정적인 수평 자세',
    stroke: '배영',
  ),
  '더블암 배영': DrillInfo(
    name: '더블암 배영',
    purpose: '입수 위치·핀치 리셋',
    method: '양팔을 동시에 스트로크합니다.',
    effect: '팔 입수 위치 인식, 양팔 동시 동작으로 밸런스 감각 리셋',
    stroke: '배영',
  ),
  '배영 사이드킥': DrillInfo(
    name: '배영 사이드킥',
    purpose: '수평 자세 훈련',
    method: '한쪽으로 누워 킥만 실시합니다.',
    effect: '수평 자세 유지, 킥 파워 집중',
    stroke: '배영',
  ),
  '배영 스핀': DrillInfo(
    name: '배영 스핀 드릴',
    purpose: '고관절 회전 연동 훈련',
    method: '팔을 빠르게 돌리며 수영합니다.',
    effect: '빠른 팔 회전과 고관절 연동, 스트로크 리듬 향상',
    stroke: '배영',
  ),
  '깃발 피하기': DrillInfo(
    name: '깃발 피하기 드릴',
    purpose: '턴 카운팅 훈련',
    method: '백스트로크 플래그 라인(5m)을 감지하여 남은 거리를 스트로크 수로 카운팅합니다.',
    effect: '벽과의 거리 감각, 안전한 턴 진입, 레이스 효율',
    stroke: '배영',
  ),
  '배영 머리 위 킥보드': DrillInfo(
    name: '배영 머리 위 킥보드 킥',
    purpose: '수평 자세·킥 파워 집중 훈련',
    method: '킥보드를 머리 위로 들고(수면 밖) 킥만 실시합니다.',
    effect: '엉덩이가 내려가지 않도록 수평 자세 강제, 킥 파워 강화',
    stroke: '배영',
  ),
  '배영 언더워터 킥아웃': DrillInfo(
    name: '배영 언더워터 킥아웃',
    purpose: '턴·출발 후 유선형 유지 훈련',
    method: '턴·출발 후 수면 아래에서 5~7킥 목표로 설정하고 스트림라인을 유지합니다.',
    effect: '유선형 자세 효율 극대화, 턴 후 속도 유지',
    stroke: '배영',
  ),

  // ── 평영 (Breaststroke) ──────────────────────────────
  '평영 2킥 1풀': DrillInfo(
    name: '평영 2킥 1풀 드릴',
    purpose: '글라이드 강조',
    method: '킥 2번, 당기기 1번을 반복합니다. 킥 후 길게 글라이드합니다.',
    effect: '글라이드 효율 향상, 저항 감소 구간 인식',
    stroke: '평영',
  ),
  '평영 글라이드': DrillInfo(
    name: '평영 글라이드 드릴',
    purpose: '저항 감소 감각 훈련',
    method: '풀 사이클 후 3초간 글라이드 자세를 유지합니다.',
    effect: '유선형 자세에서 저항 최소화 감각, 스트림라인 인식',
    stroke: '평영',
  ),
  '평영 풀만': DrillInfo(
    name: '평영 풀만(풀부이) 드릴',
    purpose: '팔 동작·타이밍 집중',
    method: '풀부이로 다리를 고정한 후 상체만으로 수영합니다.',
    effect: '팔 당기기 타이밍과 호흡 리듬 집중 훈련',
    stroke: '평영',
  ),
  '평영 킥 온 백': DrillInfo(
    name: '평영 킥 온 백 드릴',
    purpose: '발목 유연성·킥 너비 확인',
    method: '등을 대고 누운 자세에서 평영 킥만 실시합니다.',
    effect: '발목 유연성 향상, 킥 너비와 방향 시각적 확인 가능',
    stroke: '평영',
  ),
  '평영 내로우킥': DrillInfo(
    name: '평영 내로우킥 드릴',
    purpose: '저항 최소화 훈련',
    method: '좁은 킥 폭으로 평영 킥을 실시합니다.',
    effect: '킥 저항 감소, 효율적인 킥 패턴 습득',
    stroke: '평영',
  ),
  '평영 헤드업': DrillInfo(
    name: '평영 헤드업 드릴',
    purpose: '몸통 수평 자세 강화',
    method: '머리를 들고(수면 위) 수영합니다.',
    effect: '코어 근력 강화, 수평 자세 유지 능력 향상',
    stroke: '평영',
  ),
  '브레스트 스컬링': DrillInfo(
    name: '브레스트 스컬링',
    purpose: 'catch 감각 훈련',
    method: '손바닥을 아웃-인으로 움직이며 물의 저항을 느낍니다.',
    effect: '평영 catch 구간의 물 잡는 감각 향상',
    stroke: '평영',
  ),
  '평영 풀아웃': DrillInfo(
    name: '평영 풀아웃 드릴',
    purpose: '레이스 효율 핵심 훈련',
    method: '스타트·턴 후 스트림라인 → 팔 풀다운 → 글라이드 구간을 분리하여 반복합니다.',
    effect: '출발/턴 후 풀아웃 효율 극대화, 레이스 핵심 구간 완성도',
    stroke: '평영',
  ),
  '평영 분리 동작': DrillInfo(
    name: '평영 분리 동작 드릴',
    purpose: '각 국면 완성도 확인',
    method: '당기기 → 호흡 → 차기 → 뻗기 4단계를 의도적으로 분리·정지하며 실시합니다.',
    effect: '각 동작 국면의 정확도 향상, 타이밍 최적화',
    stroke: '평영',
  ),

  // ── 공통 훈련 ──────────────────────────────────────
  '킥보드 킥': DrillInfo(
    name: '킥보드 킥',
    purpose: '킥 고립 훈련',
    method: '킥보드를 잡고 킥만으로 전진합니다. 레벨별 강도를 조절합니다.',
    effect: '킥 파워 강화, 고관절 중심 킥 패턴 습득',
    stroke: '공통',
  ),
  '풀부이 풀': DrillInfo(
    name: '풀부이 풀',
    purpose: '상체 당기기 집중',
    method: '풀부이로 다리를 고정하고 팔만으로 수영합니다.',
    effect: '상체 근지구력 향상, catch 감각 강화',
    stroke: '공통',
  ),
  '빌드업': DrillInfo(
    name: '빌드업',
    purpose: '속도 전환 훈련',
    method: '시작은 쉽게, 마지막 25m에서 최대 강도로 가속합니다.',
    effect: '속도 전환 능력 향상, 워밍업에서 신경계 활성화',
    stroke: '공통',
  ),
  '디센딩': DrillInfo(
    name: '디센딩',
    purpose: '페이스 판단·심리 훈련',
    method: '매 반복마다 기록을 단축합니다. 1번째를 가장 느리게, 마지막을 가장 빠르게.',
    effect: '페이스 판단력, 점진적 강도 상승에 대한 심리적 적응',
    stroke: '공통',
  ),
  'IM 순환': DrillInfo(
    name: 'IM 순환',
    purpose: '모든 영법 균형 발달',
    method: '접영 → 배영 → 평영 → 자유형 순서로 25m씩 순환합니다.',
    effect: '영법 간 전환 훈련, 전체적인 수영 능력 균형 발달',
    stroke: '공통',
  ),
  '타바타 킥': DrillInfo(
    name: '타바타 킥',
    purpose: '무산소 킥 파워·내성 훈련',
    method: '20초 최대 강도 킥 / 10초 정지를 8사이클(총 4분) 실시합니다. 중급 이상 권장.',
    effect: 'VO2max 향상, 무산소 킥 파워 및 젖산 내성 증가',
    stroke: '공통',
  ),
  '언더워터 킥 세트': DrillInfo(
    name: '언더워터 킥 세트',
    purpose: '스트림라인·돌핀킥 효율 극대화',
    method: '출발·턴 후 수중 구간만 집중합니다. 목표 거리 15m.',
    effect: '수중 유선형 자세 향상, 출발/턴 후 속도 유지',
    stroke: '공통',
  ),
};

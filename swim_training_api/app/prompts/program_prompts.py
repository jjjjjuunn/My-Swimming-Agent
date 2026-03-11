"""수영 프로그램 생성을 위한 LLM 프롬프트"""

SYSTEM_PROMPT = """당신은 전문 수영 코치입니다. 사용자의 훈련 목표와 선호 종목에 맞는 하루 수영 훈련 프로그램을 설계합니다.

프로그램 설계 원칙:
1. 모든 프로그램은 Warm-up(워밍업), Main Set(메인 세트), Cool-down(쿨다운)으로 구성
2. 워밍업은 가벼운 수영과 드릴로 몸을 풀어주는 세트
3. 메인 세트는 훈련 목표에 맞는 핵심 훈련
4. 쿨다운은 천천히 풀어주는 이지 수영

레벨별 기준:
- 초급 (beginner): 총 800~1200m, 25m/50m 단위, 충분한 휴식(30~60초)
- 중급 (intermediate): 총 1500~2500m, 50m/100m 단위, 적당한 휴식(15~30초)  
- 고급 (advanced): 총 2500~4000m, 100m/200m 단위, 짧은 휴식(10~20초)

훈련 목표별 특징:
- 속도 (speed): 짧은 거리 고강도 반복, 스프린트 인터벌
- 지구력 (endurance): 긴 거리 일정 페이스, 지속 수영
- 테크닉 (technique): 드릴 다수 포함, 폼 교정 중심, 킥/풀 분리 훈련
- 종합 (overall): 위 요소를 골고루 배합

사용자가 선택할 수 있도록 초급, 중급, 고급 3가지 레벨의 프로그램을 모두 생성하세요.
반드시 아래 JSON 형식으로 응답하세요. 다른 텍스트는 포함하지 마세요."""

RESPONSE_FORMAT = """{
  "beginner": {
    "level": "beginner",
    "level_label": "초급",
    "description": "프로그램 요약 설명 (1줄)",
    "warmup": [
      {
        "description": "자유형 이지 수영",
        "distance": 100,
        "repeat": 1,
        "rest_seconds": 0,
        "notes": "편하게 몸 풀기"
      }
    ],
    "main_set": [...],
    "cooldown": [...],
    "total_distance": 1000,
    "estimated_minutes": 30
  },
  "intermediate": { ... },
  "advanced": { ... }
}"""


def build_user_prompt(
    training_goal: str,
    strokes: list[str],
    equipment: list[str] | None = None,
    purpose: str | None = None,
    search_history_summary: str | None = None,
    rag_context: str | None = None,
) -> str:
    """사용자 프롬프트 생성 (3개 레벨 모두 생성)"""

    goal_labels = {
        "speed": "속도 향상 (스프린트 중심)",
        "endurance": "지구력 향상 (장거리 중심)",
        "technique": "테크닉 개선 (드릴 중심)",
        "overall": "종합 체력 (밸런스)",
    }

    stroke_labels = {
        "freestyle": "자유형",
        "butterfly": "접영",
        "backstroke": "배영",
        "breaststroke": "평영",
        "IM": "개인혼영(IM)",
    }

    equipment_labels = {
        "fins": "오리발",
        "snorkel": "스노클",
        "paddles": "패들",
        "kickboard": "킥보드",
        "pull_buoy": "풀부이",
    }

    goal_text = goal_labels.get(training_goal, training_goal)
    strokes_text = ", ".join(
        [stroke_labels.get(s, s) for s in strokes]
    )

    prompt = f"""아래 조건에 맞는 하루 수영 훈련 프로그램을 초급, 중급, 고급 3가지 레벨로 만들어주세요.

## 훈련 조건
- 훈련 목표: {goal_text}
- 집중 종목: {strokes_text}
"""

    # 수영 목적 추가
    if purpose:
        purpose_labels = {
            "competition": "대회 준비 (기록 향상과 레이스 전략 중심)",
            "hobby": "취미 생활 (즐거움과 재미 위주)",
            "fitness": "체력 향상 (심폐 기능과 근력 강화)",
            "diet": "다이어트 (칼로리 소모와 지방 연소 중심)",
        }
        purpose_text = purpose_labels.get(purpose, purpose)
        prompt += f"- 수영 목적: {purpose_text}\n"

    # 도구 정보 추가
    if equipment:
        equipment_text = ", ".join(
            [equipment_labels.get(e, e) for e in equipment]
        )
        prompt += f"- 사용 가능한 도구: {equipment_text} (훈련 목표에 맞는 세트에서 적절히 활용하세요)\n"
    else:
        prompt += "- 도구 없음: 도구를 전혀 사용하지 말고 맨몸 수영만으로 구성하세요\n"

    prompt += "\n"

    if search_history_summary:
        prompt += f"""\n## 사용자 검색 이력 기반 관심사
{search_history_summary}

위 검색어를 분석하여 사용자의 관심사와 약점을 파악하세요:
- 검색어에서 특정 종목, 기술, 드릴에 대한 관심이 보이면 훈련에 자연스럽게 반영하세요
- 단, 훈련 목표와 맞을 때만 반영하세요 (예: 스프린트 목표인데 테크닉 드릴은 제외)
- 검색어가 선수 이름이면 해당 선수의 주 종목과 스타일을 참고하세요
- 과도하게 반영하지 말고, 훈련 흐름에 자연스럽게 녹아들게 하세요\n"""

    if rag_context:
        prompt += f"\n## 참고 전문 자료\n{rag_context}\n"

    prompt += f"""
## 응답 형식
아래 JSON 구조를 정확히 따르세요:
{RESPONSE_FORMAT}

프로그램 작성 시:
- beginner, intermediate, advanced 세 가지 레벨을 모두 포함
- 각 레벨의 level과 level_label을 정확히 설정
- description은 한국어로 프로그램을 1줄로 요약
- 운동 항목의 description은 한국어로 작성
- notes는 한국어로 코칭 포인트 작성
- distance는 1회 기준 거리(미터)
- total_distance는 모든 세트의 실제 총 거리
- estimated_minutes는 휴식 포함 예상 시간"""

    return prompt

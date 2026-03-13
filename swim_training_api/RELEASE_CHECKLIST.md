# Release Checklist — Swimming Coach Agent

## 테스트 실행 명령어

```bash
# 1. 서비스 단위 테스트 (워크아웃 검증, 개인화, 프롬프트 정합성)
cd swim_training_api
./venv/bin/python3 -m unittest discover -s app/services -p 'test_*.py' -v

# 2. Agent 스모크 테스트 (헬퍼, 그래프 빌드, 도구 레지스트리, 라우팅)
./venv/bin/python3 -m unittest app.agent.test_agent_smoke -v

# 3. 문법 컴파일 스모크
./venv/bin/python3 -m py_compile app/agent/tools.py
./venv/bin/python3 -m py_compile app/agent/graph.py
./venv/bin/python3 -m py_compile app/api/v1/endpoints/agent.py
./venv/bin/python3 -m py_compile app/services/personalization_feedback.py
./venv/bin/python3 -m py_compile app/services/workout_validator.py
```

## 통과 기준

| 항목 | 기준 | 현재 상태 |
|------|------|-----------|
| 서비스 테스트 | 37/37 통과 | PASS |
| Agent 스모크 | 15/15 통과 | PASS |
| py_compile | 에러 없음 | PASS |
| Zone 5 사이클 타임 | advanced 25m: 40-85초 | PASS |
| Firestore 쿼리 | inequality + order_by 분리 | PASS |
| FCM 핸들러 | 톱레벨 함수 | PASS |
| URL 보간 | user.uid 정상 치환 | PASS |

## 테스트 커버리지 범위

### 서비스 테스트 (37건)
- **WorkoutValidator**: 구조 검증, 사이클 타임 교정, Zone 강도 제한, 풀 길이 보정, 드릴 정확도, 쿨다운 Zone 강제
- **WeaknessAnalyzer**: 영법/거리 약점 감지, 강점 감지, 완주율 추세, 데이터 부족 처리
- **PersonalizationFeedback**: 피드백 정책, 볼륨/레벨 조정, 이중 적용 방지
- **ValidationProtocol**: 프롬프트 빌더, JSON 파싱, 게이트 판정

### Agent 스모크 테스트 (15건)
- **_extract_text**: str/list/dict/None 안전 변환 (7건)
- **ToolRegistry**: 도구 등록 정합성, 필수 도구 존재 (4건)
- **GraphBuild**: 그래프 컴파일, 라우팅 로직 (일반 응답/약속/미래 약속) (4건)

## Known Non-Blocking Warnings

아래 항목은 정적 분석에서 경고가 남을 수 있으나, 런타임에서 문제가 되지 않는 것으로 확인됨:

1. **Firestore SDK 타입 추론**: `document().get()` 반환 타입이 분석기에서 `Awaitable`로 추론될 수 있음.
   실제 Firebase Admin Python SDK는 동기 호출이므로 런타임에서 정상 동작.

2. **ChatOpenAI 시그니처**: `langchain_openai` 버전에 따라 파라미터 이름 경고가 발생할 수 있음.
   현재 사용 중인 버전에서는 정상 동작 확인.

## 배포 전 수동 확인 사항

- [ ] Flutter 앱 빌드 성공 (`flutter build ios` / `flutter build apk`)
- [ ] 실기기에서 FCM 알림 수신 테스트 (포그라운드 + 백그라운드)
- [ ] Agent 대화 플로우 E2E 테스트 (프로필 조회 → 컨디션 → 프로그램 생성)
- [ ] 드릴 설명 바텀시트 UI 확인
- [ ] 수영 스케줄 수정 후 홈 화면 반영 확인
- [ ] 알림 시간 변경 후 저장 → 재조회 확인

# 🏊 My Swimming Agent

> AI 기반 수영 트레이닝 코치 앱  
> AI-powered personalized swim training coach

<p align="center">
  <img src="docs/screenshots/home.png" width="200"/>
  <img src="docs/screenshots/program.png" width="200"/>
  <img src="docs/screenshots/feedback.png" width="200"/>
</p>

---

## ✨ 주요 기능

| 기능 | 설명 |
|------|------|
| 🤖 **AI 프로그램 생성** | 훈련 목표·종목·도구를 입력하면 GPT-4o-mini가 초급/중급/고급 3단계 맞춤 훈련 프로그램 생성 |
| 💬 **AI 피드백** | 최근 운동 기록과 검색 이력을 분석해 다음 훈련 처방 및 맞춤 코치 피드백 제공 |
| 📋 **피드백 → 프로그램 변환** | AI가 제안한 훈련 처방을 바로 My Program으로 저장 |
| 🎯 **My Program** | 프로그램 저장·편집·운동 실행·완료 기록 |
| 🏃 **운동 기록** | 세트별 완료 기록, 완료율, 소요 시간 자동 저장 |
| 📊 **주간/월간 통계** | 수영 거리·횟수·시간 분석 |
| 🔍 **영상 검색** | YouTube 수영 영상 검색 (한국어 자동 번역, 한국/해외 토글) |
| 🔄 **클라우드 동기화** | Firestore 기반 — 같은 계정으로 로그인하면 Android/iOS 어디서든 데이터 동기화 |

---

## 🏗️ 아키텍처

```
My-Swimming-Agent/
├── swim_training_app/      # Flutter 앱 (Android + iOS)
│   ├── lib/
│   │   ├── screens/        # 화면 UI
│   │   ├── services/       # API 클라이언트, Firestore, 로컬 서비스
│   │   ├── models/         # 데이터 모델
│   │   └── theme/          # 앱 테마 (다크 블루)
│   └── ...
│
└── swim_training_api/      # FastAPI 백엔드
    └── app/
        ├── api/v1/         # REST 엔드포인트
        ├── services/       # LLM, Firebase Admin, 프로그램 생성기
        ├── models/         # Request/Response Pydantic 모델
        └── prompts/        # LLM 프롬프트 관리
```

---

## 🛠️ 기술 스택

### Frontend (Flutter)
- **Flutter** 3.x
- **Firebase Auth** — Google 로그인
- **Cloud Firestore** — 운동 기록·프로그램 클라우드 저장
- **YouTube Player Flutter** — 인앱 영상 재생
- **share_plus** — 피드백 공유 (카톡·문자·메모 등)

### Backend (Python)
- **FastAPI** — REST API 서버
- **LangChain + OpenAI GPT-4o-mini** — 프로그램 생성 및 피드백 LLM
- **Firebase Admin SDK** — 사용자 검색 이력 조회
- **ChromaDB** — RAG 벡터 DB (현재 준비 중)

---

## 🚀 시작하기

### 사전 요구사항
- Flutter 3.x
- Python 3.11+
- Firebase 프로젝트
- OpenAI API 키

---

### 백엔드 실행 (swim_training_api)

```bash
cd swim_training_api

# 가상환경 설정
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 패키지 설치
pip install -r requirements.txt

# 환경변수 설정
cp .env.example .env
# .env 파일에 OPENAI_API_KEY, FIREBASE_CREDENTIALS_PATH 입력

# 서버 실행
uvicorn app.main:app --reload --port 8000
```

**.env 예시**
```env
OPENAI_API_KEY=sk-...
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

---

### 앱 실행 (swim_training_app)

```bash
cd swim_training_app

# Firebase 설정 파일 추가 (gitignore 제외 파일)
# android/app/google-services.json
# ios/Runner/GoogleService-Info.plist
# lib/firebase_options.dart

# 패키지 설치
flutter pub get

# 실행
flutter run
```

> **플랫폼별 API 주소**
> - Android 에뮬레이터: `10.0.2.2:8000`
> - iOS 시뮬레이터 / 실기기: `localhost:8000` 또는 서버 IP

---

## 📱 주요 화면

### 홈
- 이번 주 수영 거리 요약
- My Swim Plan (저장된 프로그램 바로가기)
- Swim History (최근 운동 기록)
- AI Feedback 카드

### Program 탭
- **AI 프로그램 생성**: 훈련 목표·종목·도구·레벨 선택
- **My Program**: 저장된 프로그램 목록, 운동 실행·편집·삭제

### 검색 탭
- YouTube 수영 영상 검색
- 한국어 입력 시 자동 영어 번역
- 한국/해외 영상 토글

### AI Feedback
1. 고민 또는 질문 입력 (선택)
2. AI가 최근 운동 기록 + 검색 이력 분석
3. 패턴 분석 / 칭찬 / 개선 포인트 / 다음 훈련 처방 제공
4. 공유하거나 My Program으로 바로 저장

---

## 🗂️ API 엔드포인트

| Method | Endpoint | 설명 |
|--------|----------|------|
| `POST` | `/api/v1/generate-program` | AI 수영 프로그램 생성 |
| `POST` | `/api/v1/ai-feedback` | 운동 기록 AI 피드백 |
| `POST` | `/api/v1/feedback-to-program` | 피드백 → 프로그램 변환 |
| `GET`  | `/api/v1/health` | 서버 상태 확인 |

---

## 🔒 보안 주의사항

아래 파일은 `.gitignore`로 관리되며 **절대 커밋하지 마세요**:

```
swim_training_api/.env
swim_training_api/firebase-credentials.json
swim_training_app/android/app/google-services.json
swim_training_app/ios/Runner/GoogleService-Info.plist
swim_training_app/macos/Runner/GoogleService-Info.plist
swim_training_app/lib/firebase_options.dart
```

---

## 📅 개발 로드맵

- [x] AI 프로그램 생성 (3단계 레벨)
- [x] 운동 기록 및 통계
- [x] AI 피드백 (운동 기록 + 검색 이력 기반)
- [x] 피드백 → My Program 자동 저장
- [x] YouTube 영상 검색
- [x] Firestore 클라우드 동기화
- [ ] Apple Login
- [ ] Kakao Login
- [ ] LangGraph Agent 전환
- [ ] RAG (수영 코칭 자료 기반)

---

## 👤 개발자

- **jjjjjuunn** — [@jjjjjuunn](https://github.com/jjjjjuunn)

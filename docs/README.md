# 📅 Desktop Schedule & Calendar Documentation (문서 목록)

본 디렉터리는 **Flutter 기반 데스크톱 스케줄 & 캘린더 애플리케이션**의 프로젝트 개요, 기능 명세서, 아키텍처 및 Google Calendar 실시간 연동 매뉴얼을 정리한 기술 문서 모음입니다.

---

## 📚 문서 목차

1. [**프로젝트 개요 및 방향성 (PROJECT_OVERVIEW.md)**](./PROJECT_OVERVIEW.md)
   - 프로젝트 정의, 목표 및 핵심 가치 (Windows 데스크톱 퍼스트 + 스마트폰 실시간 연동)
   - 기술 스택 및 디렉터리 아키텍처
   - UI/UX 디자인 시스템 및 지원 플랫폼

2. [**기능 상세 명세서 (FEATURES.md)**](./FEATURES.md)
   - 캘린더 및 일정 관리 (CRUD, 완료 토글, 검색/필터, 스마트 정렬)
   - Google 캘린더 실시간 양방향 연동 (PC ➡️ 스마트폰 푸시, 스마트폰 푸시 알림, 색상 매핑)
   - 데스크톱 특화 시스템 기능 (Single Instance 중복 실행 방지, 트레이 상주, 윈도우 닫기 제어, 부팅 시 자동 시작)
   - 백그라운드 30초 알림 엔진 및 환경설정 다이얼로그

3. [**Google 캘린더 연동 및 사용 매뉴얼 (GOOGLE_CALENDAR_MANUAL.md)**](./GOOGLE_CALENDAR_MANUAL.md)
   - Google Cloud Console API 설정 및 발급 정보 (OAuth 2.0 Client ID / Secret)
   - OAuth 2.0 Loopback 데스크톱 인증 흐름
   - 데이터 모델 매핑 테이블 (제목, 시간, 색상, 사전 알림)
   - 단계별 사용 및 스마트폰 실시간 연동 테스트 가이드

4. [**배포 및 설치 파일 생성 가이드 (RELEASE_AND_PACKAGING.md)**](./RELEASE_AND_PACKAGING.md)
   - Windows용 원클릭 설치 프로그램(`CalendarSetup.exe`) 생성 및 배포
   - macOS용 배포 파일(`Calendar-MacOS.zip`) GitHub Actions 자동 빌드 방법

5. [**구글 캘린더 연동 구현 설계서 (GOOGLE_CALENDAR_INTEGRATION_PLAN.md)**](./GOOGLE_CALENDAR_INTEGRATION_PLAN.md)
   - 연동 목표 및 동기화 알고리즘 설계
   - 증분 동기화(Incremental Sync) 및 오프라인 툼스톤(Tombstone) 관리
   - 단계별 구현 로드맵 (Phase 1 ~ Phase 5)

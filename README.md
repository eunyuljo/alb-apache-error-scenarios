# ALB + Apache Proxy 에러 시나리오

> 🔧 ALB + Apache 환경에서 발생하는 502/504 타임아웃 및 DNS 해석 문제를 시뮬레이션하고 진단.
> ALB를 구현하지 않고 docker-compose 내 nginx 로 이를 대처하고 증상만 확인.


### 🎯 학습 목표

- **타임아웃 체인 불일치**로 인한 502 에러 발생 원리
- **DNS 해석 실패**가 즉시 실패로 이어지는 과정  
- **DNS 해석 지연**이 간헐적 문제를 만드는 이유
- **서비스 불안정**이 무작위 실패로 나타나는 현상

### 🏗️ 아키텍처 개요

```
인터넷 → ALB (60초 타임아웃) → Apache Proxy (25초 타임아웃) → Backend (30-40초 응답)
```

## 🧪 제공되는 시나리오

| 시나리오 | 문제 유형 | 예상 결과 | 소요 시간 | 실제 사례 |
|----------|----------|----------|----------|----------|
| **timeout** | 프록시 타임아웃 | 25초 후 502 | ~60초 | 느린 백엔드 처리 |
| **dns-failure** | DNS 해석 실패 | 즉시 502 | ~45초 | 잘못된 호스트명/도메인 |
| **dns-delay** | DNS 해석 지연 | 초기 실패 → 나중 성공 | ~90초 | 서비스 시작 지연 |
| **dns-intermittent** | 서비스 불안정 | 불규칙한 성공/실패 | ~75초 | 재시작, Auto Scaling |

## 🚀 빠른 시작

### 전제 조건
- Docker & Docker Compose 설치
- curl 명령어 사용 가능
- 포트 80, 8080, 5000 사용 가능

### 1. 저장소 클론
```bash
git clone https://github.com/eunyuljo/alb-apache-error-scenarios.git
cd alb-apache-error-scenarios
```

### 2. 전체 설정 및 테스트
```bash
# 모든 설정 파일 자동 생성
./complete-setup.sh

# 모든 시나리오 순차 실행
./run-all-scenarios.sh
```

### 3. 개별 시나리오 실행
```bash
# 빠른 개별 테스트
./quick-test.sh timeout           # 타임아웃 시나리오
./quick-test.sh dns-failure       # DNS 실패 시나리오
./quick-test.sh dns-delay         # DNS 지연 시나리오
./quick-test.sh dns-intermittent  # 간헐적 DNS 문제
```

## 📁 프로젝트 구조

```
├── common/                           # 공통 파일
│   ├── backend-app.py               # 공통 백엔드 애플리케이션
│   └── nginx-alb.conf               # 공통 ALB 시뮬레이터 설정
├── scenarios/                       # 시나리오별 설정
│   ├── timeout/                     # 타임아웃 시나리오
│   │   ├── docker-compose.yml
│   │   ├── nginx-timeout.conf
│   │   └── apache-timeout.conf
│   ├── dns-failure/                 # DNS 실패 시나리오
│   │   ├── docker-compose.yml
│   │   ├── nginx-dns-failure.conf
│   │   └── apache-dns-fail.conf
│   ├── dns-delay/                   # DNS 지연 시나리오
│   │   ├── docker-compose.yml
│   │   ├── nginx-dns-delay.conf
│   │   └── apache-dns-slow.conf
│   └── dns-intermittent/           # 간헐적 DNS 문제
│       ├── docker-compose.yml
│       ├── nginx-dns-intermittent.conf
│       ├── apache-dns-intermittent.conf
│       └── unstable-backend.py
├── complete-setup.sh               # 전체 설정 자동 생성
├── run-all-scenarios.sh           # 모든 시나리오 실행
├── quick-test.sh                   # 개별 시나리오 빠른 실행
└── README.md                       # 이 파일
```

## 🔍 시나리오별 상세 설명

### 🔥 시나리오 1: 타임아웃 (timeout)
**상황**: Apache ProxyTimeout(25초) < Backend 응답시간(30-40초)

```bash
cd scenarios/timeout
docker-compose up -d
curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" -m 35 http://localhost/slow
# 예상 결과: Time: 25.012s, HTTP: 502
```

**실제 사례**: 복잡한 DB 쿼리, 대용량 파일 처리, 외부 API 호출 지연

### 🌐 시나리오 2: DNS 실패 (dns-failure)
**상황**: 존재하지 않는 호스트명/도메인으로 프록시 시도

```bash
cd scenarios/dns-failure
docker-compose up -d
curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" http://localhost/dns-fail-host
# 예상 결과: Time: 0.001s, HTTP: 502 (즉시 실패)
```

**실제 사례**: ECS 서비스명 오타, Private DNS Zone 설정 누락, 환경별 설정 차이

### ⏰ 시나리오 3: DNS 지연 (dns-delay)
**상황**: 서비스 시작 지연으로 인한 DNS 해석 문제

```bash
cd scenarios/dns-delay
docker-compose up -d
sleep 45  # 백엔드 시작 대기
curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" http://localhost/dns-slow
# 예상 결과: 초기 실패 → 나중 성공
```

**실제 사례**: ECS 스케일업, Kubernetes Pod 재시작, 애플리케이션 초기화 지연

### 🔄 시나리오 4: 간헐적 DNS 문제 (dns-intermittent)
**상황**: 서비스 불안정으로 인한 무작위 성공/실패

```bash
cd scenarios/dns-intermittent
docker-compose up -d
# 15회 연속 테스트로 패턴 확인
for i in {1..15}; do curl http://localhost/intermittent; sleep 2; done
# 예상 결과: 성공률 70% (불규칙한 패턴)
```

**실제 사례**: Auto Scaling, Spot Instance 중단, Circuit Breaker, 마이크로서비스 재배포

## 📊 예상 결과 비교

| 시나리오 | 에러 타입 | 응답 시간 | HTTP 코드 | 재현성 | 주요 원인 |
|---------|----------|----------|-----------|--------|----------|
| **timeout** | 프록시 타임아웃 | ~25초 | 502 | 100% | Apache ProxyTimeout |
| **dns-failure** | DNS 해석 실패 | ~0.001초 | 502 | 100% | 존재하지 않는 호스트 |
| **dns-delay** | DNS 해석 지연 | 10초 → 0.05초 | 502 → 200 | 시간 의존적 | 서비스 시작 지연 |
| **dns-intermittent** | 서비스 불안정 | 0.04초~15초 | 200/502 혼재 | 30-70% | 서비스 불안정 |

---

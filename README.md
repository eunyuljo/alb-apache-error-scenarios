# ALB + Apache Proxy 에러 시나리오

> 🔧 ALB + Apache 환경에서 발생하는 502/504 타임아웃 및 DNS 해석 문제를 시뮬레이션하고 진단합니다

## 📋 프로젝트 소개

이 프로젝트는 **ALB (Application Load Balancer) + Apache Proxy** 환경에서 발생하는 일반적인 502/504 에러를 재현하고 이해할 수 있는 **실습용 시나리오**를 제공합니다. 각 시나리오는 실제 운영환경의 문제 상황을 시뮬레이션하며, 포괄적인 로깅 및 디버깅 기능을 제공합니다.

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
git clone https://github.com/your-username/alb-apache-error-scenarios.git
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

## 🛠️ 트러블슈팅

### 컨테이너 시작 실패
```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs apache-*
docker-compose logs backend-app

# 포트 충돌 확인
netstat -tlnp | grep -E ':(80|8080|5000)'
```

### 설정 파일 문법 오류
```bash
# Apache 설정 검증
docker run --rm -v $(pwd)/apache-*.conf:/usr/local/apache2/conf/httpd.conf httpd:2.4 httpd -t

# nginx 설정 검증
docker run --rm -v $(pwd)/nginx-*.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t
```

### 네트워크 문제
```bash
# Docker 네트워크 정리
docker network prune -f

# 모든 시나리오 정리
for scenario in timeout dns-failure dns-delay dns-intermittent; do
    cd scenarios/$scenario && docker-compose down && cd ../..
done
```

## 🎯 실제 운영환경 적용

### AWS ALB + Apache 설정 예시
```apache
# 타임아웃 설정
ProxyTimeout 300  # ALB 타임아웃(900s)보다 작게 설정
Timeout 300

# 재시도 및 백업 서버
ProxyPass /api/ balancer://backend-cluster/
<Proxy balancer://backend-cluster>
    BalancerMember http://backend-1:8080
    BalancerMember http://backend-2:8080 
    BalancerMember http://backup:8080 status=+H
    ProxySet retry=3
</Proxy>

# 헬스체크 최적화
<Location "/health">
    ProxyPass http://backend:8080/health
    ProxyTimeout 30  # 헬스체크는 짧게
</Location>
```

### 모니터링 설정
```apache
# 상세 로깅
LogLevel proxy:info
LogFormat "%h %l %u %t \"%r\" %>s %b %D" combined

# 메트릭 수집용 로그
LogFormat "%{%Y-%m-%d %H:%M:%S}t [%l] %s %D %U" monitoring
CustomLog "|/usr/local/bin/log-processor" monitoring
```

## 📚 참고 자료

- [Apache HTTP Server - mod_proxy 문서](https://httpd.apache.org/docs/2.4/mod/mod_proxy.html)
- [AWS Application Load Balancer 사용자 가이드](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)
- [HTTP 502/504 에러 가이드](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [Docker Compose 네트워킹](https://docs.docker.com/compose/networking/)

## 🤝 기여하기

1. 이 저장소를 Fork 합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/amazing-feature`)
3. 변경사항을 커밋합니다 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시합니다 (`git push origin feature/amazing-feature`)
5. Pull Request를 생성합니다

## 📄 라이센스

이 프로젝트는 MIT 라이센스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 💬 문의 및 지원

- 이슈 제보: [GitHub Issues](https://github.com/your-username/alb-apache-error-scenarios/issues)
- 기능 요청: [GitHub Discussions](https://github.com/your-username/alb-apache-error-scenarios/discussions)

---

⭐ 이 프로젝트가 도움이 되었다면 Star를 눌러주세요!

## 📋 프로젝트 소개

이 프로젝트는 **ALB (Application Load Balancer) + Apache Proxy** 환경에서 발생하는 일반적인 502/504 에러를 재현하고 이해할 수 있는 **실습용 시나리오**를 제공합니다. 각 시나리오는 실제 운영환경의 문제 상황을 시뮬레이션하며, 포괄적인 로깅 및 디버깅 기능을 제공합니다.

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
git clone https://github.com/your-username/alb-apache-error-scenarios.git
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

### �� 시나리오 1: 타임아웃 (timeout)
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

## 🛠️ 트러블슈팅

### 컨테이너 시작 실패
```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 확인
docker-compose logs apache-*
docker-compose logs backend-app

# 포트 충돌 확인
netstat -tlnp | grep -E ':(80|8080|5000)'
```

### 설정 파일 문법 오류
```bash
# Apache 설정 검증
docker run --rm -v $(pwd)/apache-*.conf:/usr/local/apache2/conf/httpd.conf httpd:2.4 httpd -t

# nginx 설정 검증
docker run --rm -v $(pwd)/nginx-*.conf:/etc/nginx/nginx.conf nginx:alpine nginx -t
```

### 네트워크 문제
```bash
# Docker 네트워크 정리
docker network prune -f

# 모든 시나리오 정리
for scenario in timeout dns-failure dns-delay dns-intermittent; do
    cd scenarios/$scenario && docker-compose down && cd ../..
done
```

## 🎯 실제 운영환경 적용

### AWS ALB + Apache 설정 예시
```apache
# 타임아웃 설정
ProxyTimeout 300  # ALB 타임아웃(900s)보다 작게 설정
Timeout 300

# 재시도 및 백업 서버
ProxyPass /api/ balancer://backend-cluster/
<Proxy balancer://backend-cluster>
    BalancerMember http://backend-1:8080
    BalancerMember http://backend-2:8080 
    BalancerMember http://backup:8080 status=+H
    ProxySet retry=3
</Proxy>

# 헬스체크 최적화
<Location "/health">
    ProxyPass http://backend:8080/health
    ProxyTimeout 30  # 헬스체크는 짧게
</Location>
```

### 모니터링 설정
```apache
# 상세 로깅
LogLevel proxy:info
LogFormat "%h %l %u %t \"%r\" %>s %b %D" combined

# 메트릭 수집용 로그
LogFormat "%{%Y-%m-%d %H:%M:%S}t [%l] %s %D %U" monitoring
CustomLog "|/usr/local/bin/log-processor" monitoring
```

### CloudWatch 알람 예시
```bash
# 에러율 기반 알람
aws cloudwatch put-metric# ALB + Apache Proxy Error Scenarios

> 🔧 Simulate and diagnose 502/504 timeout and DNS resolution issues in ALB + Apache environments

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Docker](https://img.shields.io/badge/docker--compose-required-blue.svg)
![Platform](https://img.shields.io/badge/platform-linux%20%7C%20macOS-lightgrey.svg)

## 📋 Overview

This project provides **hands-on scenarios** to reproduce and understand common 502/504 errors that occur in **ALB (Application Load Balancer) + Apache Proxy** environments. Each scenario simulates real-world production issues with comprehensive logging and debugging capabilities.

### 🎯 What You'll Learn

- How **timeout chain mismatches** cause 502 errors
- When **DNS resolution failures** lead to immediate failures  
- Why **DNS resolution delays** create intermittent issues
- How **service instability** manifests as random failures

### 🏗️ Architecture Overview

```
Internet → ALB (60s timeout) → Apache Proxy (25s timeout) → Backend (30-40s response)
```

## 🧪 Available Scenarios

| Scenario | Problem Type | Expected Result | Duration | Use Case |
|----------|-------------|-----------------|----------|----------|
| **timeout** | Proxy timeout | 502 after 25s | ~60s | Slow backend processing |
| **dns-failure** | DNS resolution failure | 502 immediately | ~45s | Wrong hostnames/domains |
| **dns-delay** | DNS resolution delay | 502

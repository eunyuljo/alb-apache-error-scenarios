#!/bin/bash

echo "=== ALB + Apache 확장 시나리오 테스트 ==="

SCENARIOS=("timeout" "dns-failure" "dns-delay" "dns-intermittent")

for scenario in "${SCENARIOS[@]}"; do
    echo ""
    echo "========================================="
    echo "시나리오 ${scenario} 테스트 시작"
    echo "========================================="
    
    cd "scenarios/${scenario}" || continue
    
    # 이전 컨테이너 정리
    docker-compose down 2>/dev/null
    
    # 컨테이너 시작
    echo "컨테이너 시작 중..."
    docker-compose up -d
    
    echo "서비스 준비 대기 (30초)..."
    sleep 30
    
    echo "컨테이너 상태 확인:"
    docker-compose ps
    
    echo ""
    echo "=== ${scenario} 시나리오 테스트 ==="
    
    case $scenario in
        "timeout")
            echo "1. nginx 헬스체크:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/nginx-health 2>/dev/null || echo "Failed"
            
            echo "2. 정상 응답 테스트:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/normal 2>/dev/null || echo "Failed"
            
            echo "3. 타임아웃 테스트 (25초 후 502 예상):"
            echo "   (이 테스트는 시간이 오래 걸립니다...)"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 35 http://localhost/slow 2>/dev/null || echo "Timed out (expected)"
            ;;
            
        "dns-failure")
            echo "1. nginx 헬스체크:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/nginx-health 2>/dev/null || echo "Failed"
                 
            echo "2. 정상 DNS 해석:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/health 2>/dev/null || echo "Failed"
            
            echo "3. 존재하지 않는 호스트명 (즉시 502 예상):"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/dns-fail-host 2>/dev/null || echo "Failed (expected)"
            
            echo "4. 존재하지 않는 도메인 (즉시 502 예상):"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/dns-fail-domain 2>/dev/null || echo "Failed (expected)"
            
            echo "5. 잘못된 포트 (연결 실패 예상):"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/port-fail 2>/dev/null || echo "Failed (expected)"
            ;;
            
        "dns-delay")
            echo "1. nginx 헬스체크:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/nginx-health 2>/dev/null || echo "Failed"
                 
            echo "2. 정상 응답:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/health 2>/dev/null || echo "Failed"
            
            echo "3. DNS 지연 테스트 (초기 실패 예상):"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 15 http://localhost/dns-slow 2>/dev/null || echo "Failed (expected - backend not ready)"
            
            echo "4. 40초 대기 후 재시도 (성공 예상):"
            sleep 20
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 15 http://localhost/dns-slow 2>/dev/null || echo "Failed"
            ;;
            
        "dns-intermittent")
            echo "1. nginx 헬스체크:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/nginx-health 2>/dev/null || echo "Failed"
                 
            echo "2. 정상 응답:"
            curl -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
                 -m 10 http://localhost/health 2>/dev/null || echo "Failed"
            
            echo "3. 간헐적 DNS 문제 테스트 (10회 시도):"
            for i in {1..10}; do
                echo -n "   시도 $i: "
                curl -w "Time: %{time_total}s, HTTP: %{http_code}" \
                     -m 20 http://localhost/intermittent 2>/dev/null || echo "Failed"
                echo ""
                sleep 3
            done
            ;;
    esac
    
    echo ""
    echo "=== Apache 에러 로그 (최근 5개) ==="
    docker-compose logs --tail=5 apache-* 2>/dev/null | grep -E "(error|Error|ERROR|timeout|Timeout)" || echo "No error logs found"
    
    echo ""
    echo "시나리오 ${scenario} 완료. 정리 중..."
    docker-compose down 2>/dev/null
    
    cd ../..
    
    echo "다음 시나리오까지 5초 대기..."
    sleep 5
done

echo ""
echo "========================================="
echo "모든 시나리오 테스트 완료!"
echo "========================================="
echo ""
echo "개별 시나리오 실행 방법:"
echo "cd scenarios/timeout && docker-compose up -d"
echo "cd scenarios/dns-failure && docker-compose up -d"
echo "cd scenarios/dns-delay && docker-compose up -d"
echo "cd scenarios/dns-intermittent && docker-compose up -d"

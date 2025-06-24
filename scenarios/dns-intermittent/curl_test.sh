#!/bin/bash

success_count=0
total_count=15

for i in $(seq 1 $total_count); do
    echo -n "시도 $i: "
    result=$(curl -w "Time:%{time_total}s,HTTP:%{http_code}" -s -m 20 http://localhost/intermittent 2>/dev/null)

    if echo "$result" | grep -q "HTTP:200"; then
        echo "$result ✅"
        ((success_count++))
    else
        echo "$result ❌"
    fi

    sleep 3
done

from flask import Flask
import time
import random
import os
import sys
import threading

app = Flask(__name__)

# 30-120초 후 랜덤 종료
shutdown_after = random.randint(30, 120)

@app.route('/health')
def health():
    return "Unstable backend OK"

@app.route('/intermittent')
def intermittent():
    # 30% 확률로 지연 발생
    if random.random() < 0.3:
        delay = random.randint(5, 15)
        print(f"Intermittent delay: {delay}s")
        time.sleep(delay)
    return "Intermittent response from unstable backend"

@app.route('/')
def hello():
    return f"Unstable backend running (will shutdown in ~{shutdown_after}s)"

def shutdown_timer():
    time.sleep(shutdown_after)
    print(f"Auto-shutdown after {shutdown_after} seconds")
    os._exit(0)

if __name__ == '__main__':
    print(f"Starting unstable backend (auto-shutdown in {shutdown_after}s)")
    
    # 백그라운드 종료 타이머
    timer = threading.Thread(target=shutdown_timer)
    timer.daemon = True
    timer.start()
    
    app.run(host='0.0.0.0', port=5000, debug=True)

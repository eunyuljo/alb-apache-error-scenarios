from flask import Flask, request
import time
import random
import os

app = Flask(__name__)

server_name = os.getenv('SERVER_NAME', 'backend-default')

@app.route('/')
def hello():
    return f"Backend {server_name} is running!"

@app.route('/slow')
def slow_endpoint():
    # 30-40초 지연 (타임아웃 테스트용)
    delay = random.randint(30, 40)
    print(f"Processing request with {delay}s delay...")
    time.sleep(delay)
    return f"Response from {server_name} after {delay} seconds"

@app.route('/normal')
def normal_endpoint():
    return f"Normal fast response from {server_name}"

@app.route('/health')
def health_check():
    return "OK"

@app.route('/intermittent')
def intermittent_endpoint():
    # 50% 확률로 지연 발생
    if random.choice([True, False]):
        delay = random.randint(5, 15)
        print(f"Intermittent delay: {delay}s")
        time.sleep(delay)
    return f"Intermittent response from {server_name}"

if __name__ == '__main__':
    print(f"Starting {server_name} on port 5000")
    app.run(host='0.0.0.0', port=5000, debug=True)

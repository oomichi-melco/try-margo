import datetime
import http.server
import json
import threading
import time
import subprocess

PORT = 8080

result = subprocess.run(["uname", "-r"], capture_output=True, text=True)
kernel_version = result.stdout.strip()

result = subprocess.run(["cat", "/sys/class/dmi/id/product_name"], capture_output=True, text=True)
edge_product_name = result.stdout.strip()

print(f"kernel_version: {kernel_version}")
print(f"edge_product_name: {edge_product_name}")

last_tick = None


class StatusHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        body = json.dumps({
            "status": "ok",
            "kernel_version": kernel_version,
            "edge_product_name": edge_product_name,
            "last_tick": last_tick,
        }).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


server = http.server.ThreadingHTTPServer(("", PORT), StatusHandler)
threading.Thread(target=server.serve_forever, daemon=True).start()
print(f"Serving the status on port {PORT}")

print("Starting the program. If stopping, please press Ctrl+C")

try:
    while True:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        last_tick = now
        print(f"Now: {now}")
        time.sleep(10)

except KeyboardInterrupt:
    print("\nStopped")

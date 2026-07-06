import datetime
import time
import subprocess

result = subprocess.run(["uname", "-r"], capture_output=True, text=True)
kernel_version = result.stdout.strip()

result = subprocess.run(["cat", "/sys/class/dmi/id/product_name"], capture_output=True, text=True)
edge_product_name = result.stdout.strip()

print(f"kernel_version: {kernel_version}")
print(f"edge_product_name: {edge_product_name}")

print("Starting the program. If stopping, please press Ctrl+C")

try:
    while True:
        now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"Now: {now}")
        time.sleep(10)

except KeyboardInterrupt:
    print("\nStopped")

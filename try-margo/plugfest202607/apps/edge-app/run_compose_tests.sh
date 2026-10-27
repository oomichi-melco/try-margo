#!/bin/bash

cd $(dirname "$0")

docker compose version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo \
	  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
	  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
	  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	sudo apt update
	sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	docker compose version
fi

sudo usermod -aG docker $USER

echo "Running docker compose.."
cd ./docker-compose
docker compose up -d
sleep 10

echo "Checking container status.."
docker ps | grep Up
if [ $? -ne 0 ]; then
	echo "Failed to get valid status container."
	docker ps -a
	docker compose logs
	exit 1
fi

echo "Checking the published port and the health status.."
HOST_PORT=$(docker compose port main 8080 | awk -F: '{print $NF}')
curl -sf "http://localhost:${HOST_PORT}/"
if [ $? -ne 0 ]; then
	echo "Failed to get the status from the published port ${HOST_PORT}."
	docker compose logs
	exit 1
fi
echo
for i in $(seq 1 12); do
	docker compose ps | grep -q "(healthy)" && break
	sleep 5
done
docker compose ps | grep -q "(healthy)"
if [ $? -ne 0 ]; then
	echo "The container did not become healthy."
	docker compose ps
	docker compose logs
	exit 1
fi

echo "Succeeded to run this script."

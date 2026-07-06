#!/bin/bash

cd $(dirname "$0")

podman --version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y podman
fi

CONTAINER_IMAGE="localhost/edge-app:latest"

podman run -d ${CONTAINER_IMAGE}
sleep 2
podman ps | grep "${CONTAINER_IMAGE}"
if [ $? -ne 0 ]; then
	echo "Failed to run ${CONTAINER_IMAGE}"
	podman ps -a
	exit 1
fi

echo "Succeeded to build the container image."

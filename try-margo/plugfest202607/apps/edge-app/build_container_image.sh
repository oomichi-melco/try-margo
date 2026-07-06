#!/bin/bash

cd $(dirname "$0")

IMAGE_NAME=edge-app

MULTI_ARCH_BUILD=${MULTI_ARCH_BUILD:-"false"}

rm -rf $(find . -name __pycache__)

podman --version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y podman
fi

set +e
podman rmi --force ${IMAGE_NAME}
set -e

if [ "${MULTI_ARCH_BUILD}" == "false" ]; then
	podman build -t ${IMAGE_NAME} .
else
	sudo podman run --rm --privileged docker.io/multiarch/qemu-user-static --reset -p yes
	podman build --platform linux/amd64,linux/arm64 --format docker -t ${IMAGE_NAME} .
fi

set +x
echo "Succeeded to build the container image."

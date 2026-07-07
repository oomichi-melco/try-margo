#!/bin/bash

cd $(dirname "$0")

CONTAINER_IMAGE="oomichi-melco/edge-app:develop"
HELM_IMAGE="oomichi-melco/edge-app-chart:1.0.0"

podman --version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y podman
fi

echo "Pushing container image.."
set -ex
podman logout ghcr.io
podman pull ghcr.io/${CONTAINER_IMAGE}
podman tag ghcr.io/${CONTAINER_IMAGE} harbor.machine:8443/${CONTAINER_IMAGE}
podman login harbor.machine:8443 -u admin -p Harbor12345
podman push harbor.machine:8443/${CONTAINER_IMAGE}
set +x

echo "Pushing helm chart.."
set -ex
podman pull ghcr.io/${HELM_IMAGE}
podman save -o helm.tar ghcr.io/${HELM_IMAGE}
helm push helm.tar oci://harbor.machine:8443/library

echo "Succeeded to run this script."

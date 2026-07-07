#!/bin/bash

cd $(dirname "$0")

CONTAINER_IMAGE="oomichi-melco/edge-app:develop"
HELM_IMAGE="oomichi-melco/edge-app-chart:1.0.0"

podman --version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y podman
fi

echo "Pushing container image to harbor.."
set -ex
docker pull ghcr.io/${CONTAINER_IMAGE}
docker tag ghcr.io/${CONTAINER_IMAGE} harbor.machine:8443/${CONTAINER_IMAGE}
docker login harbor.machine:8443 -u admin -p Harbor12345
docker push harbor.machine:8443/${CONTAINER_IMAGE}
set +x

echo "Pushing helm chart.."
set -ex
docker pull ghcr.io/${HELM_IMAGE}
docker save -o helm.tar ghcr.io/${HELM_IMAGE}
helm push helm.tar oci://harbor.machine:8443/library

echo "Succeeded to run this script."

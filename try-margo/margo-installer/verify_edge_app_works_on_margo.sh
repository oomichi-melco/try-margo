#!/bin/bash

cd $(dirname "$0")

CONTAINER_IMAGE="edge-app:develop"
HELM_IMAGE="edge-app-chart:1.0.0"

podman --version
if [ $? -ne 0 ]; then
	sudo apt update
	sudo apt install -y podman
fi

echo "Pushing container image to harbor.."
set -ex
docker pull ghcr.io/oomichi-melco/${CONTAINER_IMAGE}
docker tag ghcr.io/oomichi-melco/${CONTAINER_IMAGE} harbor.machine:8443/library/${CONTAINER_IMAGE}
docker login harbor.machine:8443 -u admin -p Harbor12345
docker push harbor.machine:8443/library/${CONTAINER_IMAGE}
set +x

echo "Pushing helm chart to harbor.."
set -x
cd ../plugfest202607/apps/edge-app/helm-chart/
helm package .
helm push edge-app-chart-1.0.0.tgz oci://harbor.machine:8443/library --plain-http
helm push edge-app-chart-1.0.0.tgz oci://harbor.machine:8443/library

echo "Succeeded to run this script."

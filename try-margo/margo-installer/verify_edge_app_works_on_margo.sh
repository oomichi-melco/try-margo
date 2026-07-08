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
helm push edge-app-chart-1.0.0.tgz oci://harbor.machine:8443/library
set +x
cd ~-

echo "Pushing application package to harbor.."
set -x
echo "Harbor12345" | oras login harbor.machine:8443   -u admin --password-stdin
cd ../plugfest202607/apps/edge-app/application-description/
oras push harbor.machine:8443/library/edge-app-helm-app-package:latest \
  --artifact-type "application/vnd.margo.app.v1+json" \
  margo.yaml:application/vnd.margo.app.description.v1+yaml
set +ex
cd ~-

cd sandbox/scripts

echo "Uploading application package.."
sudo -E bash wfm-cli.sh upload-app-non-interactive edge-app-helm-app-package
if [ $? -ne 0 ]; then
	echo "Failed to upload application package for edge-app-helm-app-package."
	exit 1
fi

echo "Checking application packages.."
sudo -E bash wfm-cli.sh list-packages | grep ONBOARD
if [ $? -ne 0 ]; then
	echo "Failed to get any ONBOARDED application packages."
	exit 1
fi

PACKAGE_ID=$(sudo -E bash wfm-cli.sh list-packages | grep ONBOARD | awk -F'|' '{print $2}' | sed s/" "//g)
if [ -z "${PACKAGE_ID}" ]; then
	echo "Failed to get PACKAGE_ID."
	sudo -E bash wfm-cli.sh list-packages | grep ONBOARD
	exit 1
fi

K3S_DEVICE_ID=$(sudo -E bash wfm-cli.sh list-devices | grep ONBOARD | grep 'Standalone Cluster' | awk -F'|' '{print $2}' | sed s/" "//g)
if [ -z "${K3S_DEVICE_ID}" ]; then
	echo "Failed to get K3S_DEVICE_ID."
	sudo -E bash wfm-cli.sh list-devices
	exit 1
fi

DOCKER_DEVICE_ID=$(sudo -E bash wfm-cli.sh list-devices | grep ONBOARD | grep 'Standalone Device' | awk -F'|' '{print $2}' | sed s/" "//g)
if [ -z "${DOCKER_DEVICE_ID}" ]; then
	echo "Failed to get DOCKER_DEVICE_ID."
	sudo -E bash wfm-cli.sh list-devices
	exit 1
fi

echo "K3S_DEVICE_ID   : ${K3S_DEVICE_ID}"
echo "DOCKER_DEVICE_ID: ${DOCKER_DEVICE_ID}"

DEVICE_ID=${DOCKER_DEVICE_ID}

# to make it stable
sleep 10

echo "Deploying application on edge.."
sudo -E bash wfm-cli.sh deploy-non-interactive ${PACKAGE_ID} ${DEVICE_ID}
if [ $? -ne 0 ]; then
	echo "Failed to deploy application on edge."
	exit 1
fi

# to make it stable
sleep 10

echo "Logs of symphony-api-container ----------------------------------------------------------"
sudo docker logs symphony-api-container

sleep 10

echo "Checking deployment.."
sudo -E bash wfm-cli.sh list-deployments

cd ~-

echo "Succeeded to run this script."

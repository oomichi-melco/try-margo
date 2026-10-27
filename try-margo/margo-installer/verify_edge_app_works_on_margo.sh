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

# Devices are identified by the SPIFFE ID now, so tell them apart by DEPLOYMENT TYPE.
K3S_DEVICE_ID=$(sudo -E bash wfm-cli.sh list-devices | grep ONBOARD | grep -w helm | awk -F'|' '{print $2}' | sed s/" "//g)
if [ -z "${K3S_DEVICE_ID}" ]; then
	echo "Failed to get K3S_DEVICE_ID."
	sudo -E bash wfm-cli.sh list-devices
	exit 1
fi

DOCKER_DEVICE_ID=$(sudo -E bash wfm-cli.sh list-devices | grep ONBOARD | grep -w compose | awk -F'|' '{print $2}' | sed s/" "//g)
if [ -z "${DOCKER_DEVICE_ID}" ]; then
	echo "Failed to get DOCKER_DEVICE_ID."
	sudo -E bash wfm-cli.sh list-devices
	exit 1
fi

echo "K3S_DEVICE_ID   : ${K3S_DEVICE_ID}"
echo "DOCKER_DEVICE_ID: ${DOCKER_DEVICE_ID}"

# Wait until the deployment on the device ends up in a terminal state.
# $1: label of the device (for messages), $2: the last part of the device ID
wait_deployment_running() {
	local label=$1
	local device_suffix=$2
	local state
	local i

	for i in $(seq 1 30); do
		# columns: | ID | NAME | PKG | DEVICE | OP | RUNNINGSTATE | UPDATED |
		state=$(sudo -E bash wfm-cli.sh list-deployments | grep "${device_suffix}" | awk -F'|' '{print $7}' | sed s/" "//g)
		echo "[${i}/30] ${label} deployment state: ${state:-(not found)}"
		case "${state}" in
		INSTALLED|RUNNING)
			return 0
			;;
		FAILED)
			return 1
			;;
		esac
		sleep 10
	done
	return 1
}

# to make it stable
sleep 10

echo "Deploying application on edge (k3s).."
sudo -E bash wfm-cli.sh deploy-non-interactive ${PACKAGE_ID} ${K3S_DEVICE_ID}
if [ $? -ne 0 ]; then
	echo "Failed to deploy application on k3s device."
	exit 1
fi

echo "Deploying application on edge (docker).."
sudo -E bash wfm-cli.sh deploy-non-interactive ${PACKAGE_ID} ${DOCKER_DEVICE_ID}
if [ $? -ne 0 ]; then
	echo "Failed to deploy application on docker device."
	exit 1
fi

echo "Waiting for deployments to be running.."
RESULT=0
wait_deployment_running k3s "${K3S_DEVICE_ID##*/}"
if [ $? -ne 0 ]; then
	echo "The deployment on the k3s device did not get running."
	RESULT=1
fi
wait_deployment_running docker "${DOCKER_DEVICE_ID##*/}"
if [ $? -ne 0 ]; then
	echo "The deployment on the docker device did not get running."
	RESULT=1
fi

echo "Checking deployment.."
sudo -E bash wfm-cli.sh list-deployments

echo "Checking the app on the devices.."
kubectl get pods -A | grep edge-app | grep Running
if [ $? -ne 0 ]; then
	echo "No running edge-app pod on the k3s device."
	kubectl get pods -A
	RESULT=1
fi
sudo docker ps --filter name=melcoedgeapp --filter status=running | grep melcoedgeapp
if [ $? -ne 0 ]; then
	echo "No running melcoedgeapp container on the docker device."
	sudo docker ps -a
	RESULT=1
fi

if [ ${RESULT} -ne 0 ]; then
	echo "Logs of symphony-api-container ----------------------------------------------------------"
	sudo docker logs symphony-api-container
	echo "Failed to verify that edge-app is running."
	exit 1
fi

cd ~-

echo "Succeeded to run this script."

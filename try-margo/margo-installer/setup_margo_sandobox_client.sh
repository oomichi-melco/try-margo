#!/bin/bash

cd $(dirname "$0")

if [ ! -d ./sandbox ]; then
	echo "Cloning sandbox repo.."
	git clone --filter=blob:none --sparse https://github.com/margo/sandbox.git
	cd sandbox
	git sparse-checkout init --no-cone
	git sparse-checkout set scripts/*
	git checkout main
else
	cd sandbox
fi

cd scripts

RUNNER_IP=$(hostname -I | awk '{print $1}')

echo "Install margo k3s client.."
sudo -E bash device-agent.sh k3s install
if [ $? -ne 0 ]; then
	echo "Failed to install margo k3s client."
	exit 1
fi
sudo chown $(id -u):$(id -g) "$HOME/.kube/config"

kubectl get nodes
if [ $? -ne 0 ]; then
	echo "Failed to run kubectl."
	exit 1
fi

echo "Create Security Certificates of rsa for k3s.."
sudo -E bash device-agent.sh k3s create-rsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of rsa."
	exit 1
fi

echo "Create Security Certificates of ecdsa for k3s.."
sudo -E bash device-agent.sh k3s create-ecdsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of ecdsa."
	exit 1
fi

ls ~/certs

set -ex
sudo cp ~/symphony/api/certificates/ca-cert.pem ~/certs
sudo cp ~/sandbox/scripts/harbor/certs/harbor.crt ~/certs
set +ex

echo "Changing coredns file.."
set -ex
pwd
cd ../..
kubectl -n kube-system get configmap coredns -o yaml > ./coredns.yaml
patch -p0 < ./nodehosts.patch
sed -i s/"127.0.0.1"/"${RUNNER_IP}"/g ./coredns.yaml
kubectl apply -f ./coredns.yaml
kubectl -n kube-system rollout restart deployment coredns
cd sandbox/scripts
set +ex

echo "Starting k3s agent.."
export CI=false
sudo -E bash device-agent.sh k3s start-k3s
if [ $? -ne 0 ]; then
	echo "Failed to start k3s agent."
	exit 1
fi

# NOTE: k3s-agent and compose-agent use the same cert files.
# To avoid the same signature on api side, here generates cert files again after start-k3s.
echo "Create Security Certificates of rsa for docker.."
sudo -E bash device-agent.sh docker create-rsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of rsa."
	exit 1
fi

echo "Create Security Certificates of ecdsa for docker.."
sudo -E bash device-agent.sh docker create-ecdsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of ecdsa."
	exit 1
fi

echo "Starting docker-compose agent.."
sudo -E bash device-agent.sh docker start-docker
if [ $? -ne 0 ]; then
	echo "Failed to start docker-compose agent."
	exit 1
fi

kubectl -n default get pods
kubectl -n default wait --timeout=1m --for=condition=ready pod -l app=workload-fleet-management-client-pod
if [ $? -ne 0 ]; then
	echo "Failed to wait for the pod ready."
	exit 1
fi

# this sleep is necessary for onboarding process.
sleep 1m

echo "Checking k3s agent logs.."
kubectl -n default get deployments
kubectl -n default logs deployment/workload-fleet-management-client-deploy | grep "Device onboarded"
if [ $? -ne 0 ]; then
	kubectl -n default logs deployment/workload-fleet-management-client-deploy
	echo "Failed to get valid message for k3s device onboarding process."
	exit 1
fi

echo "Checking k3s agent status.."
sudo -E bash device-agent.sh k3s status
if [ $? -ne 0 ]; then
	echo "Failed to check k3s agent status."
	exit 1
fi

echo "Checking logs of docker-compose agent.."
sudo docker logs workload-fleet-management-client 2>&1 | grep 'Device onboarded'
if [ $? -ne 0 ]; then
	echo "Failed to get valid message for docker device onboarding process."
	exit 1
fi

echo "Installing otel.."
# Fix this later.
# sudo -E bash device-agent.sh k3s otel-install
if [ $? -ne 0 ]; then
	echo "Failed to install otel."
	exit 1
fi

echo "Succeeded to run this script."

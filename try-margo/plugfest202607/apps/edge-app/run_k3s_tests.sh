#!/bin/bash

cd $(dirname "$0")

helm version
if [ $? -eq 127 ]; then
	curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
	sudo apt-get install apt-transport-https --yes
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
	sudo apt-get update
	sudo apt-get install helm
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
if [ $? -ne 0 ]; then
	echo "Installing k3s.."
	../../../tests/install_k3s.sh
fi

echo "Running helm install.."
helm install my-release ./helm-chart
if [ $? -ne 0 ]; then
	echo "Failed to run helm install."
	exit 1
fi

sleep 10

echo "Checking edge-app exists.."
kubectl get pods -A | grep edge-app
if [ $? -ne 0 ]; then
	echo "Failed to check edge-app is running."
	kubectl get pods -A
	exit 1
fi

echo "Checking edge-app is ready.."
kubectl wait --timeout=1m --for=condition=ready pod -l app=edge-app
if [ $? -ne 0 ]; then
	echo "Failed to check edge-app is ready."
	echo "--- kubectl get pods ---------------------------------------------"
	kubectl get pods
	echo "--- kubectl describe pods ----------------------------------------"
	kubectl describe pods
	exit 1
fi

echo "Succeeded to run this script."

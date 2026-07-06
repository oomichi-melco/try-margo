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

helm lint ./helm-chart/
if [ $? -ne 0 ]; then
	echo "Failed to run helm lint."
	exit 1
fi

helm install my-release ./helm-chart --dry-run
if [ $? -ne 0 ]; then
	echo "Failed to run helm install --dry-run."
	exit 1
fi

echo "Succeeded to run this script."

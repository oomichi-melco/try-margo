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

echo "Create Security Certificates of rsa.."
sudo -E bash device-agent.sh k3s create-rsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of rsa."
	exit 1
fi

echo "Create Security Certificates of ecdsa.."
sudo -E bash device-agent.sh k3s create-ecdsa-certs
if [ $? -ne 0 ]; then
	echo "Failed to create Security Certificates of ecdsa."
	exit 1
fi

echo "Copy cert files to device client.."
if [ ! -d ~/certs ]; then
	mkdir ~/certs
fi

set -ex
sudo cp ~/symphony/api/certificates/ca-cert.pem ~/certs
sudo cp ~/sandbox/scripts/harbor/certs/harbor.crt ~/certs
set +ex

echo "Changing coredns file.."
kubectl -n kube-system get configmap coredns -o yaml

echo "Succeeded to run this script."

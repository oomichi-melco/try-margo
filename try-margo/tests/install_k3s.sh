#!/bin/bash

k3s --version 2>/dev/null
if [ $? -ne 0 ]; then
	set -e
	# Install k3s single-node
	# NOTE: Cannot install k3s into a container.
	export INSTALL_K3S_SKIP_SELINUX_RPM=true
	curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE="666" sh -
	set +e
fi

KUBECONFIG_MOD=$(find /etc/rancher/k3s/k3s.yaml -ls | awk '{print $3}')
if [ "${KUBECONFIG_MOD}" == "-rw-------" ]; then
	sudo chmod 666 /etc/rancher/k3s/k3s.yaml
fi
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

kubectl get nodes
if [ $? -ne 0 ]; then
	echo "Failed to run kubectl get nodes"
	exit 1
fi

echo
echo "Succeeded to run this script($0)."

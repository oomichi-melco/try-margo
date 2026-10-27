#!/bin/bash

cd $(dirname "$0")

if [ ! -d ./sandbox ]; then
	echo "Cloning sandbox repo.."
	git clone --filter=blob:none --sparse https://github.com/margo/sandbox.git
	cd sandbox
	git sparse-checkout init --no-cone
	git sparse-checkout set scripts/*
	git checkout "${SANDBOX_COMMIT:-a8b4ac90d88991c5842a418960827ff3287b9bce}"
else
	cd sandbox
fi

cd scripts

RUNNER_IP=$(hostname -I | awk '{print $1}')

# device-agent.sh install requires ~/certs to hold the MIS CA, the harbor cert and
# an SVID (identity) of the WFM client for each device type.
TRUST_DOMAIN=margo.org
WFM_SPIFFE_ID="spiffe://${TRUST_DOMAIN}/margo/wfm/sandbox-wfm"

generate_client_svid() {
	local identity_dir=$1
	local client_id=$2

	sudo -E bash lib/mis/svid-gen.sh --automated --principal wfm-client \
		--spiffe-id "${WFM_SPIFFE_ID}/client/${client_id}" || return 1
	mkdir -p ~/certs/${identity_dir}
	sudo cp x509svid-wfmclient/payload-cert.pem x509svid-wfmclient/payload-key.pem ~/certs/${identity_dir}/
	sudo chown -R $(id -u):$(id -g) ~/certs/${identity_dir}
}

echo "Prepare certificates for margo client.."
mkdir -p ~/certs
cp ~/mis-deployment/certs/https-ca.crt ~/certs/
cp ~/sandbox/scripts/harbor/certs/harbor.crt ~/certs/
generate_client_svid helm-identity sandbox-client-k3s
if [ $? -ne 0 ]; then
	echo "Failed to generate SVID for k3s client."
	exit 1
fi
generate_client_svid compose-identity sandbox-client-docker
if [ $? -ne 0 ]; then
	echo "Failed to generate SVID for docker client."
	exit 1
fi
ls -R ~/certs

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

echo "Place SPIFFE ID allowlists of the WFM.."
set -ex
mkdir -p ~/sandbox/docker-compose/config ~/sandbox/helmchart/authorized
echo "[\"${WFM_SPIFFE_ID}\"]" > ~/sandbox/helmchart/authorized/authorized.json
echo "[\"${WFM_SPIFFE_ID}\"]" > ~/sandbox/docker-compose/config/authorized.json
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

echo "Install margo docker client.."
sudo -E bash device-agent.sh docker install
if [ $? -ne 0 ]; then
	echo "Failed to install margo docker client."
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

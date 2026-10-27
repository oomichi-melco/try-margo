#!/bin/bash

cd $(dirname "$0")

git clone --filter=blob:none --sparse https://github.com/margo/sandbox.git
cd sandbox
git sparse-checkout init --no-cone
git sparse-checkout set scripts/*
git checkout main

echo "Installing necessary packages.."
UBUNTU_CODENAME=noble
set -e
sudo apt update
sudo apt install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
set +e

RUNNER_IP=$(hostname -I | awk '{print $1}')

echo "Adding entries for /etc/hosts.."
grep symphony.machine /etc/hosts
if [ $? -ne 0 ]; then
	echo "${RUNNER_IP} symphony.machine" | sudo tee -a /etc/hosts > /dev/null
	echo "${RUNNER_IP} harbor.machine" | sudo tee -a /etc/hosts > /dev/null
fi

cd scripts

echo "Setup margo.."
sudo -E bash wfm.sh install
if [ $? -ne 0 ]; then
	echo "Failed to setup margo."
	exit 1
fi

# Since margo/sandbox switched to MIS (Margo Identity Service) based authentication,
# symphony requires a WFM SVID, the MIS HTTPS CA and a non-empty SPIFFE ID allowlist.
TRUST_DOMAIN=margo.org
WFM_SPIFFE_ID="spiffe://${TRUST_DOMAIN}/margo/wfm/sandbox-wfm"
WFM_CLIENT_SPIFFE_IDS="\"${WFM_SPIFFE_ID}/client/sandbox-client-k3s\",\"${WFM_SPIFFE_ID}/client/sandbox-client-docker\""

echo "Adding entries for /etc/hosts.."
grep mis.${TRUST_DOMAIN} /etc/hosts
if [ $? -ne 0 ]; then
	echo "${RUNNER_IP} mis.${TRUST_DOMAIN}" | sudo tee -a /etc/hosts > /dev/null
fi

# CI=false makes mis.sh use the ghcr image instead of a locally built one.
echo "Setup MIS root CAs.."
CI=false sudo -E bash mis.sh setup-factory
if [ $? -ne 0 ]; then
	echo "Failed to setup MIS root CAs."
	exit 1
fi

echo "Start MIS.."
CI=false sudo -E bash mis.sh mis-install
if [ $? -ne 0 ]; then
	echo "Failed to start MIS."
	exit 1
fi

echo "Generate WFM SVID.."
sudo -E bash lib/mis/svid-gen.sh --automated --principal wfm --spiffe-id "${WFM_SPIFFE_ID}"
if [ $? -ne 0 ]; then
	echo "Failed to generate WFM SVID."
	exit 1
fi

echo "Place WFM SVID, MIS CA and SPIFFE ID allowlist.."
set -ex
ls -l x509svid-wfm
sudo cp x509svid-wfm/* ~/symphony/api/certificates/
sudo cp ~/mis-deployment/certs/https-ca.crt ~/symphony/api/mis/https-ca.crt
echo "[${WFM_CLIENT_SPIFFE_IDS}]" | sudo tee ~/symphony/api/mis/authorized-clients.json > /dev/null
set +ex

echo "Start symphony.."
sudo -E bash wfm.sh start
if [ $? -ne 0 ]; then
	echo "Failed to start symphony."
	exit 1
fi

echo "Install observability_stack.."
# Fix this later.
# sudo -E bash wfm.sh obs-install
if [ $? -ne 0 ]; then
	echo "Failed to install observability_stack."
	exit 1
fi

sleep 10

sudo docker logs symphony-api-container | grep 'evaluation context established'
if [ $? -ne 0 ]; then
	echo "Failed to check valid logs in symphony-api-container."
	exit 1
fi

echo "Succeeded to run this script."

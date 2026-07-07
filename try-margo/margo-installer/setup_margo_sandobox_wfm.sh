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

echo "Adding entries for /etc/hosts.."
grep symphony.machine /etc/hosts
if [ $? -ne 0 ]; then
	echo "127.0.0.1 symphony.machine" | sudo tee -a /etc/hosts > /dev/null
	echo "127.0.0.1 harbor.machine" | sudo tee -a /etc/hosts > /dev/null
fi

cd scripts

echo "Setup margo.."
sudo -E bash wfm.sh install
if [ $? -ne 0 ]; then
	echo "Failed to setup margo."
	exit 1
fi

echo "Start symphony.."
sudo -E bash wfm.sh start
if [ $? -ne 0 ]; then
	echo "Failed to start symphony."
	exit 1
fi

echo "Install observability_stack.."
# TODO: Fix this later
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

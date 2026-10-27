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

echo "checking ONBOARDED devices.."
sudo -E bash wfm-cli.sh list-devices
sudo -E bash wfm-cli.sh list-devices | grep ONBOARDED
if [ $? -ne 0 ]; then
	echo "Failed to get any ONBOARDED devices."
	exit 1
fi

echo "Succeeded to run this script."

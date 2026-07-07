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

sudo -E bash wfm-cli.sh list-devices

echo "Succeeded to run this script."

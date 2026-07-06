#!/bin/bash

cd $(dirname "$0")

TARGET=$1

IMAGE_TAG=${IMAGE_TAG:-"develop"}

if [ "${REGISTRY}" == "" ]; then
	echo "REGISTRY needs to be specified."
	exit 1
fi
if [ "${REGISTRY_TOKEN_NAME}" == "" ]; then
	echo "REGISTRY_TOKEN_NAME needs to be specified."
	exit 1
fi
if [ "${REGISTRY_TOKEN_PASSWD}" == "" ]; then
	echo "REGISTRY_TOKEN_PASSWD needs to be specified."
	exit 1
fi

function push_image() {
	IMAGE_NAME=$1
	NEW_REGISTRY_IMAGE="${REGISTRY}/oomichi-melco/${IMAGE_NAME}:${IMAGE_TAG}"

	set -e
	echo "Pushing the image ${IMAGE_NAME}:${IMAGE_TAG}.."
	podman tag localhost/${IMAGE_NAME}:latest ${NEW_REGISTRY_IMAGE}
	podman push ${NEW_REGISTRY_IMAGE}
	set +e
}

set -e
podman login -u "${REGISTRY_TOKEN_NAME}" -p "${REGISTRY_TOKEN_PASSWD}" "${REGISTRY}"
set +e

if [ "${TARGET}" == "" ]; then
	push_image edge-app
else
	push_image "${TARGET}"
fi

echo "Succeeded to push container images."

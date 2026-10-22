#!/bin/bash

cd $(dirname $0)

MARKDOWNLIT_IMAGE="mirror.gcr.io/davidanson/markdownlint-cli2:v0.14.0"

podman pull ${MARKDOWNLIT_IMAGE}

IGNORED_FILES=$(cat ./.markdownlintignore)

cd ../../
MD_FILES=$(git ls-files | grep "\.md$")

for mfile in ${MD_FILES}; do
	FLAG_IGNORED=false
	for ifile in ${IGNORED_FILES}; do
		if [ "${mfile}" == "${ifile}" ]; then
			echo "${mfile}" should be ignored.
			FLAG_IGNORED=true
			break
		fi
	done
	if [ "${FLAG_IGNORED}" == "true" ]; then
		continue
	fi
	podman run -v "${PWD/../}":/workdir ${MARKDOWNLIT_IMAGE} --config try-margo/tests/.markdownlint.json "${mfile}"
	if [ $? -ne 0 ]; then
		echo "Failed to check markdown style for ${mfile}."
		exit 1
	fi
done

echo
echo "Succeeded to run markdownlint for checking markdown style."

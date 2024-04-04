#!/bin/bash

set -e

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ] ; do SOURCE="$(readlink "$SOURCE")"; done
SCRIPTDIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# IMPORTANT note that this script's working directory is the parent of this script's directory
cd $SCRIPTDIR/..

KNOWN_TARGETS=()
count=0
for e in $(cat "$SCRIPTDIR/build.cfg"); do
	if [ $count -ge 2 ]; then
		KNOWN_TARGETS[${#KNOWN_TARGETS[@]}]="${KNOWN_TARGET}"
		unset KNOWN_TARGET
		count=0
	fi

	if [ -z "$KNOWN_TARGET" ]; then
		KNOWN_TARGET="${e}"
		if [ -z "$TARGET_NAMES" ]; then
			TARGET_NAMES="${e}"
		else
			TARGET_NAMES="${TARGET_NAMES}|${e}"
		fi
	else
		KNOWN_TARGET="${KNOWN_TARGET} ${e}"
	fi
	count=$((count+1))
done
if [ -n "$KNOWN_TARGET" ]; then
	KNOWN_TARGETS[${#KNOWN_TARGETS[@]}]="${KNOWN_TARGET}"
	unset KNOWN_TARGET
fi

TARGETS=()
while getopts "t:" opt; do
	case "${opt}" in
		t)
			TARGETS[${#TARGETS[@]}]=${OPTARG}
			;;
		:)
			echo "Usage: $0 -t (${TARGET_NAMES})" >&2
			exit 1
			;;
	esac
done
shift $((OPTIND - 1))

if [ ${#TARGETS[@]} -lt 1 ]; then
	echo "Usage: $0 -t (${TARGET_NAMES})" >&2
	exit 1
fi

function clean() {
	rm -rf dist/*
	rm -rf build/*
}

function build_and_deploy {
	repo="$1"

	clean

	poetry build

	echo "Setting environment variable TWINE_USERNAME: __token__"
	export TWINE_USERNAME="__token__"
	if [ -z "$TWINE_PASSWORD" ]; then
		echo "Missing environment variable: TWINE_PASSWORD"
		exit 1
	fi

	if [ "$repo" == "pypi" ]; then
		twine upload \
			--skip-existing \
			dist/*
	elif [ "$repo" == "testpypi" ]; then
		twine upload \
			--skip-existing \
			--repository testpypi \
			dist/*
	else
		echo "Unknown repo: ${repo}"
		exit 2
	fi

	clean
}

for i in "${KNOWN_TARGETS[@]}"; do
	parts=($i)
	if [[ "${TARGETS[*]}" == "${parts[0]}" ]]; then
		echo "Building and uploading: ${parts[0]}"
		repo_url="${parts[1]}"
		build_and_deploy "${repo_url}"
	fi
done

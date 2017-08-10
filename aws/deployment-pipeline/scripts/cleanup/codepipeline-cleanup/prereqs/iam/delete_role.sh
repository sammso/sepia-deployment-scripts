#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

while getopts ":n:" opt; do
  case ${opt} in
    n) APPLICATION_NAME="${OPTARG}"
    ;;
    \?) echo "Invalid option -${OPTARG}" >&2
    exit 1
    ;;
  esac
done

set -x

ROLE_NAME="CodeBuildServiceRole-${APPLICATION_NAME}"

aws iam delete-role --role-name ${ROLE_NAME}
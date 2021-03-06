#!/usr/bin/env bash

set -euo pipefail

while getopts "c:" OPT; do
  case ${OPT} in
    c) CONFIG_DIR="${OPTARG}"
    ;;
    \?) echo "Invalid option -${OPTARG}" >&2
    exit 1
    ;;
  esac
done

echo "CONFIG_DIR: ${CONFIG_DIR}"

set -o allexport
source ${CONFIG_DIR}/setup_deployment_pipeline.env
set +o allexport

printf "Values used: \n"
printf "COMMIT_MESSAGE_PREFIX: %s\n" "${COMMIT_MESSAGE_PREFIX}"
printf "DEPLOYMENT_ARTIFACTS_BRANCH: %s\n" "${DEPLOYMENT_ARTIFACTS_BRANCH}"
printf "DEPLOYMENT_ARTIFACTS_ORG: %s\n" "${DEPLOYMENT_ARTIFACTS_ORG}"
printf "DEPLOYMENT_ARTIFACTS_REPO: %s\n" "${DEPLOYMENT_ARTIFACTS_REPO}"
printf "DOCKER_IMAGE_NAME: %s\n" "${DOCKER_IMAGE_NAME}"
printf "DOCKER_IMAGE_VERSION: %s\n" "${DOCKER_IMAGE_VERSION}"
printf "DOCKER_ORG: %s\n" "${DOCKER_ORG}"
printf "\n"

# Echo commands with expanded variables
set -x


# Clone deployment repository
cd ${TRAVIS_BUILD_DIR}/..

git clone --depth=5 --branch=${DEPLOYMENT_ARTIFACTS_BRANCH} https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${DEPLOYMENT_ARTIFACTS_ORG}/${DEPLOYMENT_ARTIFACTS_REPO}.git

DEPLOYMENT_REPO_DIR=${TRAVIS_BUILD_DIR}/../${DEPLOYMENT_ARTIFACTS_REPO}

## Update Dockerrun.aws.json

PATH_TO_EB_DOCKER_JSON_FILE=${DEPLOYMENT_REPO_DIR}/Dockerrun.aws.json

# Update docker image version. Commit and push change.

jq --join-output --tab '.containerDefinitions[0].image = "'${DOCKER_ORG}'/'${DOCKER_IMAGE_NAME}':'${DOCKER_IMAGE_VERSION}'"' ${PATH_TO_EB_DOCKER_JSON_FILE} |sponge ${PATH_TO_EB_DOCKER_JSON_FILE}

# Configure authentication bucket name

jq '.authentication.bucket = "'${BUCKET_NAME}'"' ${PATH_TO_EB_DOCKER_JSON_FILE}|sponge ${PATH_TO_EB_DOCKER_JSON_FILE}

# Configure docker image

jq '.containerDefinitions[0].image = "'${DOCKER_ORG}'/'${DOCKER_IMAGE_NAME}':'${DOCKER_IMAGE_VERSION}'"' ${PATH_TO_EB_DOCKER_JSON_FILE}|sponge ${PATH_TO_EB_DOCKER_JSON_FILE}

# Configure container image

jq '.containerDefinitions[0].name = "'${APPLICATION_NAME}'"' ${PATH_TO_EB_DOCKER_JSON_FILE}|sponge ${PATH_TO_EB_DOCKER_JSON_FILE}


## Update .elasticbeanstalk/config.yml

PATH_TO_CONFIG_YML_FILE=${DEPLOYMENT_REPO_DIR}/.elasticbeanstalk/config.yml

# Configure global application name

cat ${PATH_TO_CONFIG_YML_FILE} | docker run -i --rm jlordiales/jyparser set ".global.application_name" \"${APPLICATION_NAME}\"|sponge ${PATH_TO_CONFIG_YML_FILE}


# Add changed files

cd ${DEPLOYMENT_REPO_DIR}

git add ${PATH_TO_EB_DOCKER_JSON_FILE}
git add ${DEPLOYMENT_REPO_DIR}/.elasticbeanstalk/config.yml

# Commit

git commit -m "${COMMIT_MESSAGE_PREFIX} DOCKER_IMAGE_VERSION: ${DOCKER_IMAGE_VERSION}. Trigger TRAVIS_COMMIT: ${TRAVIS_COMMIT}. TRAVIS_BUILD_ID=${TRAVIS_BUILD_ID}"


# Push

git push
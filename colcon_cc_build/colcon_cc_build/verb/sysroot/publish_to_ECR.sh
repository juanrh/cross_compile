#!/usr/bin/env bash

######################
# Usage
#
# ```` 
# # Assumming AWS credentials are setup
# export AWS_DEFAULT_REGION=us-west-2 # or another target region
# ./publish_to_ECR.sh ubuntu_arm64_prebuilt crystal
# ```
# where
# - ubuntu_arm64_prebuilt refers to a Dockerfile in this directory
# - crystal refers to a branch on https://github.com/ros2/ros2/

# Exit on error
set -e

script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
repo_name=ros2

function setup_docker_copy_resources {
    mkdir -p docker
    pushd docker
    #   qemu files
    mkdir -p  qemu-user-static
    cp /usr/bin/qemu-*-static qemu-user-static
    #   ROS 2 source
    wget https://raw.githubusercontent.com/ros2/ros2/${ros2_version}/ros2.repos
    mkdir -p src
    vcs-import src < ros2.repos
    popd
}

function create_ecr_repo {
    # Creates an ECR repo if missing, and prints the repo URI on stdout
    repo_name="${1}"
    aws ecr describe-repositories --repository-names ${repo_name} &> /dev/null || aws ecr create-repository --repository-name ${repo_name}
    repo_uri=$(aws ecr describe-repositories --repository-names ${repo_name} | jq -r '.repositories[0].repositoryUri')
    echo "${repo_uri}"
}

sysroot_image="${1}"
ros2_version="${2}"
sysroot_image_tag_qual="${sysroot_image}-${ros2_version}"
sysroot_image_tag="${repo_name}:${sysroot_image_tag_qual}"
echo "Building and publishing image [${sysroot_image_tag}]"
sysroot_image_path="${script_dir}/Dockerfile_${sysroot_image}"
ls ${sysroot_image_path} &> /dev/null || (echo "Unable to find image file ${sysroot_image_path}" && exit 1)

echo "Building image [${sysroot_image_tag}]"
# setup resources for Docker COPY
pushd "${script_dir}"
ls docker &> /dev/null || setup_docker_copy_resources
pushd docker
docker build --network host -t "${sysroot_image_tag}" -f "${sysroot_image_path}" .
popd
popd

echo "Publishing image [${sysroot_image}]"
echo "Logging into the Docker registry"
login_cmd=$(aws ecr get-login --no-include-email)
${login_cmd}

repo_uri=$(create_ecr_repo "${repo_name}")
echo "Publishing ${sysroot_image_tag} to ${repo_uri}:${sysroot_image_tag_qual}"
docker tag "${sysroot_image_tag}" "${repo_uri}:${sysroot_image_tag_qual}"
docker push "${repo_uri}:${sysroot_image_tag_qual}"


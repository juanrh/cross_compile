#!/bin/bash
set -ex

# NOTE: we cannot do `set -u` as some variables like COLCON_TRACE will be unset on the 
# setup.bash for the sysroot

# FIXME: a suitable SYSROOT_IMAGE should be part of the plugin 
function setup_sysroot_image {
    case ${PACKAGE_REPOS} in
        "crystal_core")
            SYSROOT_IMAGE="juanrh/ros2:armhf_bionic_crystal_base-crystal"
            ;;
        *)
            SYSROOT_IMAGE="juanrh/ros2:armhf_bionic_crystal_fastrtps_prebuilt-crystal"
            ;;  
    esac
}

function setup_source_code {
    mkdir src
    pushd src
    case ${PACKAGE_REPOS} in
        "crystal_core")
            wget https://raw.githubusercontent.com/ros2/ros2/crystal/ros2.repos
            vcs-import . < ros2.repos
            rm ros2.repos
            # disable non core packages, as in https://github.com/ros2/cross_compile/blob/master/entry_point.sh#L46
            touch ros2/rviz/COLCON_IGNORE ros-visualization/COLCON_IGNORE
            # disable demos using Fortran bindings
            touch ros2/demos/image_tools/COLCON_IGNORE ros2/demos/intra_process_demo/COLCON_IGNORE
            ;;
        *)
            for PACKAGE_REPO in ${PACKAGE_REPOS}
            do
                git clone ${PACKAGE_REPO}
            done
            ;;  
    esac
    popd
}

mkdir -p workspace
pushd workspace

setup_sysroot_image
setup_source_code

colcon cc-setup-sysroot --arch ${ARCH} --os ${OS} \
    --distro ${ROS_DISTRO} --rmw ${RMW} \
    --sysroot-base-image ${SYSROOT_IMAGE}
CC_ROOT="${ARCH}-${OS}-${RMW}-${ROS_DISTRO}"
bash ${CC_ROOT}/cc_system_setup.bash

source ${CC_ROOT}/cc_build_setup.bash
colcon cc-build --arch ${ARCH} --os ${OS} \
    --distro ${ROS_DISTRO} --rmw ${RMW}

popd

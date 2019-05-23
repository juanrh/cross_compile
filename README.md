# Colcon cc-build

Colcon pluing for cross-compilation

## Usage 

### Install prerequisites 

The cross compilation toolchain and docker have to be installed. The following instruction have been tested on Ubuntu Xenial.

```bash
# Install cross compilation toolchain
sudo apt-get update
sudo apt-get install -y build-essential cmake git wget curl lsb-core bash-completion qemu-user-static g++-aarch64-linux-gnu g++-arm-linux-gnueabihf python3-pip htop
sudo python3 -m pip install -U  colcon-common-extensions rosdep vcstool
pip3 install awscli --upgrade --user

# Also install docker and make it available to the current user: https://docs.docker.com/install/linux/docker-ce/ubuntu/
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo usermod -aG docker $USER
newgrp docker # this reloads the group permissions in the current shell, unnecessary after relogin
docker run hello-world
```

### Building a workspace

```bash
# assuming AWS credentials are setup.
#   in case of error "Unknown options: --no-include-email", then upgrade
#   AWS CLI with `pip3 install awscli --upgrade --user`
ecr_login=$(aws --region us-west-2 ecr get-login --no-include-email)
${ecr_login}

# Install plugin
pip3 install --editable src/Colcon-cc-build/colcon_cc_build --user

# Launch a build
## 1. setup the sysroot
## add --force-sysroot-build to force rebuilding the sysroot
colcon cc-setup-sysroot --arch generic_arm64 --os ubuntu_bionic \
   --sysroot-base-image 913674827342.dkr.ecr.us-west-2.amazonaws.com/ros2:ubuntu_arm64_prebuilt-crystal
## 2. Complete cc-build setup following the instructions in the output of the previous command
bash generic_arm64-ubuntu_bionic-fastrtps-crystal/cc_system_setup.bash
source generic_arm64-ubuntu_bionic-fastrtps-crystal/cc_build_setup.bash
## 3. launch cross compilation using that sysroot
colcon cc-build --arch generic_arm64 --os ubuntu_bionic \
  --packages-up-to examples_rclcpp_minimal_publisher
```

### Assumptions

- Base images are created using the script `publish_to_ECR.sh` at the [`additional-sysroots` branch of the `RO2_Cross_Compile` package](https://code.amazon.com/packages/RO2_Cross_Compile/trees/heads/additional-sysroots)
- The Docker image for `--sysroot-base-image` install the ROS 2 distro at `/opt/ros/${distro}`. These commands are designed to **cross compile a ROS 2 package, not to cross compoile a ROS 2 distro**

### TODOs

- We could reduce cross compiling ROS 2 to cross compiling a workspace using these commands by
  1. Use a minimal base image with just the build tools, and get a sysroot from it without ROS. 
  2. Run `colcon cc-build` without sourcing setup.bash, that gets us a ROS 2 build in `install`        subdirectory of the cc-root
  3. Build a final base image with ROS 2 pre-built by starting with the image from step 1. and 
     copying the ROS 2 installation from step 2.

### Debug

Manually build and/or run the workspace image

```bash
docker image build -f src/Colcon-cc-build/colcon_cc_build/colcon_cc_build/verb/sysroot/Dockerfile_workspace \
  --network host \
  -t ros2_benchmark_pipeline:latest \
  --build-arg ROS2_BASE_IMG=913674827342.dkr.ecr.us-west-2.amazonaws.com/ros2:ubuntu_arm-crystal \
  --build-arg ROS2_WORKSPACE=. --build-arg ROS_DISTRO=crystal --build-arg TARGET_TRIPLE=aarch64-linux-gnu \
  .

docker container run -it --rm --network=host --name test ros2_benchmark_pipeline:latest bash
```

Manually cross compile a package using an existing sysroot

```bash
# e.g. for generic_arm64-ubuntu_bionic-fastrtps-crystal
export TARGET_ARCH=aarch64
export TARGET_TRIPLE=aarch64-linux-gnu
CC_ROOT="$(pwd)/generic_arm64-ubuntu_bionic-fastrtps-crystal"
export SYSROOT="${CC_ROOT}/sysroot"
export ROS2_INSTALL_PATH="${SYSROOT}/opt/ros/crystal"
source ${ROS2_INSTALL_PATH}/setup.bash

colcon build --merge-install --cmake-force-configure \
    --packages-up-to examples_rclcpp_minimal_publisher \
    --cmake-args \
        -DCMAKE_VERBOSE_MAKEFILE=ON \
        -DCMAKE_TOOLCHAIN_FILE="$(pwd)/src/Colcon-cc-build/colcon_cc_build/colcon_cc_build/verb/cmake-toolchains/generic_linux.cmake" \
        -DTARGET_ARCH=${TARGET_ARCH} -DSYSROOT=${SYSROOT} -DTARGET_TRIPLE=${TARGET_TRIPLE} \
    --build-base "${CC_ROOT}/build" \
    --install-base "${CC_ROOT}/install"
```

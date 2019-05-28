# colcon-cc-build

An extension for [colcon-core](https://github.com/colcon/colcon-core) for cross-compiling ROS 2 packages.

## Development setup

### Prerequisites

```bash
apt-get install -y python3-pip python3-apt
pip3 install stdeb --user
# Tested on Ubuntu 16.04.6
sudo apt-get install fakeroot python3-all
```

### Build, package the extension with pip, and install locally

```bash
# from the parent directory for this file
pip3 install --editable .
```

and now we should be able to

```bash
# list the extension
$ colcon extensions --all | grep cc-build
  cc-build: Cross-compile ROS 2 packages
# use the extension
colcon cc-build --help
```

### Package the extension as a Debian package

```bash
python3 setup.py --command-packages=stdeb.command bdist_deb
```
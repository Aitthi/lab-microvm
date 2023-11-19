#!/bin/bash
# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# fail if we encounter an error, uninitialized variable or a pipe breaks
EXEC=$1
set -eu -o pipefail

set -x
PS4='+\t '

cd $(dirname $0)
ARCH=$(uname -m)
BASE_DIR=$PWD/../fs_img
OUTPUT_DIR=$BASE_DIR/$ARCH
mkdir -p $OUTPUT_DIR

# Make sure we have all the needed tools
function install_dependencies {
    sudo apt update
    sudo apt install -y bc flex bison gcc make libelf-dev libssl-dev squashfs-tools busybox-static tree cpio curl
}

function get_linux_git {
    # git clone -s -b v$KV ../../linux
    # --depth 1
    cd linux
    LATEST_TAG=$(git tag -l "v$KV.*" --sort=v:refname |tail -1)
    git clean -fdx
    git checkout $LATEST_TAG
}


# Download the latest kernel source for the given kernel version
function get_linux_tarball {
    local KERNEL_VERSION=$1
    echo "Downloading the latest patch version for v$KERNEL_VERSION..."
    local major_version="${KERNEL_VERSION%%.*}"
    local url_base="https://cdn.kernel.org/pub/linux/kernel"
    local LATEST_VERSION=$(
        curl -fsSL $url_base/v$major_version.x/ \
        | grep -o "linux-$KERNEL_VERSION\.[0-9]*\.tar.xz" \
        | sort -rV \
        | head -n 1 || true)
    # Fetch tarball and sha256 checksum.
    curl -fsSLO "$url_base/v$major_version.x/sha256sums.asc"
    mv $PWD/sha256sums.asc $BASE_DIR
    curl -fsSLO "$url_base/v$major_version.x/$LATEST_VERSION"
    # Verify checksum.
    grep "${LATEST_VERSION}" $BASE_DIR/sha256sums.asc | sha256sum -c -
    mv $PWD/$LATEST_VERSION $BASE_DIR
    echo "Extracting the kernel source..."
    tar -xaf $BASE_DIR/$LATEST_VERSION -C $BASE_DIR
    local DIR=$(basename $BASE_DIR/$LATEST_VERSION .tar.xz)
    ln -svfT $DIR $BASE_DIR/linux
}

function build_linux {
    local KERNEL_CFG=$1
    # Extract the kernel version from the config file provided as parameter.
    local KERNEL_VERSION=$(grep -Po "^# Linux\/\w+ \K(\d+\.\d+)" "$KERNEL_CFG")

    get_linux_tarball $KERNEL_VERSION
    pushd $BASE_DIR/linux

    arch=$(uname -m)
    if [ "$arch" = "x86_64" ]; then
        format="elf"
        target="vmlinux"
        binary_path="$target"
    elif [ "$arch" = "aarch64" ]; then
        format="pe"
        target="Image"
        binary_path="arch/arm64/boot/$target"
    else
        echo "FATAL: Unsupported architecture!"
        exit 1
    fi
    cp "$KERNEL_CFG" .config

    make olddefconfig
    make -j $(nproc) $target
    LATEST_VERSION=$(cat include/config/kernel.release)
    flavour=$(basename $KERNEL_CFG .config |grep -Po "\d+\.\d+\K(-.*)" || true)
    OUTPUT_FILE=$OUTPUT_DIR/vmlinux-$LATEST_VERSION$flavour
    cp -v $binary_path $OUTPUT_FILE
    cp -v .config $OUTPUT_FILE.config
    make modules
    popd &>/dev/null
}

# Build a rootfs for Alpine Linux
function build_alpine_rootfs {
    rm -f $BASE_DIR/rootfs.ext4
    dd if=/dev/zero of=$BASE_DIR/rootfs.ext4 bs=1M count=1000
    mkfs.ext4 $BASE_DIR/rootfs.ext4
    rootfs=/tmp/my-rootfs
    mkdir -p $rootfs
    mount $BASE_DIR/rootfs.ext4 $rootfs

    # Generate key for ssh access from host
    if [ ! -s id_rsa ]; then
        ssh-keygen -f id_rsa -N ""
    fi
    sudo install -d -m 0600 "$rootfs/root/.ssh/"
    sudo mv id_rsa.pub "$rootfs/root/.ssh/authorized_keys"
    id_rsa=$OUTPUT_DIR/id_rsa
    sudo mv id_rsa $id_rsa

    KERNEL_VERSION=$(grep -Po "^# Linux\/\w+ \K(\d+\.\d+\.\d+)" "$BASE_DIR/linux/.config")

    mkdir -p $rootfs/lib/modules/$KERNEL_VERSION/kernel
    cp $BASE_DIR/linux/modules.builtin $rootfs/lib/modules/$KERNEL_VERSION
    cp $BASE_DIR/linux/modules.builtin.modinfo $rootfs/lib/modules/$KERNEL_VERSION
    cp $BASE_DIR/linux/modules.order $rootfs/lib/modules/$KERNEL_VERSION

    # temp
    cp $BASE_DIR/linux/scripts/depmod.sh $rootfs/
    cp $BASE_DIR/linux/System.map $rootfs/

    docker run -i --rm \
        -v $rootfs:/my-rootfs \
        -v $PWD/rootfs:/rootfs \
        -e KERNEL_VERSION=$KERNEL_VERSION \
        --privileged \
        alpine sh < modules.sh

    docker run -i --rm \
        -v $rootfs:/my-rootfs \
        -v $PWD/rootfs:/rootfs \
        --privileged \
        alpine sh < setup-alpine.sh

    umount $rootfs
    
    cp $BASE_DIR/rootfs.ext4 $BASE_DIR/x86_64/alpine.ext4
}


#### main ####
install_dependencies

if [ $EXEC == "rootfs" ]; then
# from docker image
build_alpine_rootfs
fi

# linux kernel
if [ $EXEC == "kernel" ]; then
build_linux $PWD/guest_configs/microvm-kernel-ci-$ARCH-6.1.config
# if [ $ARCH == "aarch64" ]; then
#     build_linux $PWD/guest_configs/microvm-kernel-ci-$ARCH-5.10-no-sve.config vmlinux-no-sve
# fi
fi
tree -h $OUTPUT_DIR

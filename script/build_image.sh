#!/bin/bash
# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# fail if we encounter an error, uninitialized variable or a pipe breaks
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

# Build a rootfs
function build_alpine_rootfs {
    rm -f $BASE_DIR/rootfs.ext4
    dd if=/dev/zero of=$BASE_DIR/rootfs.ext4 bs=1M count=1000
    mkfs.ext4 $BASE_DIR/rootfs.ext4
    mkdir -p /tmp/my-rootfs
    mount $BASE_DIR/rootfs.ext4 /tmp/my-rootfs

    docker run -i --rm \
        -v /tmp/my-rootfs:/my-rootfs \
        alpine sh < setup-alpine.sh

    umount /tmp/my-rootfs
    cp $BASE_DIR/rootfs.ext4 $BASE_DIR/x86_64/alpine.ext4
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
    popd &>/dev/null
}

#### main ####
install_dependencies

# from docker image
build_alpine_rootfs

# linux kernel
build_linux $PWD/guest_configs/microvm-kernel-ci-$ARCH-6.1.config
# if [ $ARCH == "aarch64" ]; then
#     build_linux $PWD/guest_configs/microvm-kernel-ci-$ARCH-5.10-no-sve.config vmlinux-no-sve
# fi

tree -h $OUTPUT_DIR

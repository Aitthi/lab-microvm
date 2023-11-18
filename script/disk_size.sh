e2fsck -f ubuntu-22.04.ext4 -y
resize2fs ubuntu-22.04.ext4 +1G # or qemu-img resize ubuntu-22.04.ext4 +1G

# in guest
# resize2fs /dev/vda
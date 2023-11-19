mkdir -p /lib/modules/$KERNEL_VERSION
cp -r /my-rootfs/lib/modules/$KERNEL_VERSION /lib/modules
cp /my-rootfs/System.map / 
chmod +x /my-rootfs/depmod.sh
/my-rootfs/depmod.sh depmod $KERNEL_VERSION
cp -r /lib/modules/$KERNEL_VERSION /my-rootfs/lib/modules
ls -la /my-rootfs/lib/modules/$KERNEL_VERSION
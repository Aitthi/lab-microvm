apk add --no-cache openrc
apk add --no-cache util-linux
# apk add --no-cache gcc libc-dev
# apk add --no-cache python2 python3
# apk add --no-cache go
# apk add --no-cache g++
apk add --no-cache openssh-server

ln -s agetty /etc/init.d/agetty.ttyS0
echo ttyS0 > /etc/securetty
rc-update add agetty.ttyS0 default

echo "root:root" | chpasswd
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "dev-vm" >> /etc/hostname

addgroup -g 1000 -S dev-vm && adduser -u 1000 -S dev-vm -G dev-vm

rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot
rc-update add agent boot
rc-update add local default
rc-update add sshd default

# net.start 
cp net.start /etc/local.d/net.start

for d in bin etc lib root sbin usr; do tar c "/$d" | tar x -C /my-rootfs; done
for dir in dev proc run sys var tmp; do mkdir /my-rootfs/${dir}; done

chmod 1777 /my-rootfs/tmp
mkdir -p /my-rootfs/home/dev-vm/
chown 1000:1000 /my-rootfs/home/dev-vm/
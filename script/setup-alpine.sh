apk add --no-cache openrc
apk add --no-cache util-linux
apk add --no-cache openssh-server
apk add --no-cache curl
apk add --no-cache git
apk add --no-cache zsh
apk add --no-cache htop

ln -s agetty /etc/init.d/agetty.ttyS0
echo ttyS0 > /etc/securetty
rc-update add agetty.ttyS0 default

echo "root:root" | chpasswd
sed -i 's/\/bin\/ash/\/bin\/zsh/g' /etc/passwd
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo "dev-vm" >> /etc/hostname

addgroup -g 1000 -S dev-vm && adduser -u 1000 -S dev-vm -G dev-vm

sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

rc-update add devfs boot
rc-update add procfs boot
rc-update add sysfs boot
rc-update add agent boot
rc-update add sshd boot

# net-start 
cp /rootfs/net-start.sh /etc/local.d/net.start
chmod +x /etc/local.d/net.start
rc-update add local default

for d in bin etc lib root sbin usr; do tar c "/$d" | tar x -C /my-rootfs; done
for dir in dev proc run sys var tmp; do mkdir /my-rootfs/${dir}; done

chmod 1777 /my-rootfs/tmp
mkdir -p /my-rootfs/home/dev-vm/
chown 1000:1000 /my-rootfs/home/dev-vm/
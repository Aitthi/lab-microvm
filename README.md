# lab micro VM
Just lab


# Requirements dev

```sh
Debian >=12
Rust >=1.74 nightly
Docker
```
```sh
apt install cmake
apt install gcc
apt install clang
```

## On The Host

The first step on the host is to create a `tap` device:

```bash
ip tuntap add tap0 mode tap
```

Then you have a few options for routing traffic out of the tap device, through
your host's network interface. One option is NAT, set up like this:

```bash
ip addr add 172.16.0.1/24 dev tap0
ip link set tap0 up
sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward"
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i tap0 -o eth0 -j ACCEPT

### KVM

Firecracker requires [the KVM Linux kernel module](https://www.linux-kvm.org/).

The presence of the KVM module can be checked with:

```bash
lsmod | grep kvm
```

An example output where it is enabled:

INTEL
```bash
kvm_intel             348160  0
kvm                   970752  1 kvm_intel
irqbypass              16384  1 kvm
```
AMD
```bash
kvm_amd               155648  0
ccp                   118784  1 kvm_amd
kvm                  1142784  1 kvm_amd
irqbypass              16384  1 kvm
```

# Running
```sh
# build kernel and rootfs
chmod +x ./script/build_image.sh
./script/build_image.sh kernel
./script/build_image.sh rootfs
```

```sh
# run
cargo run
```

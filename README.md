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

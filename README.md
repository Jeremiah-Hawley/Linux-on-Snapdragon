# Linux-on-Snapdragon
Figuring how to set up linux (arch) on the snapdragon X elite, this is my notes for figuring everything out
(mostly folllowing https://gist.github.com/joske/52be3f1e5d0239706cd5a4252606644b, but with ubuntu kernel instead of qualcomm's)

# Bootsrapping
It appears that there are three options for linux on the X Elite chip, 
1) You use the debian-esque distro from qualcomm https://git.codelinaro.org/linaro/qcomlt/demos/debian-12-installer-image
2) You use the Ubuntu 24.10 Concept https://discourse.ubuntu.com/t/ubuntu-24-10-concept-snapdragon-x-elite/48800
3) You use the sub-par arch linux on arm (https://archlinuxarm.org/platforms/armv8/generic) generic with the qualcomm or ubuntu kernel
4) You could try to install gentoo, and use the newest gentoo kernel, or the ubuntu/qualcomm kernel

# Arch
1) Download Ubuntu for X Elite (https://people.canonical.com/~platform/images/ubuntu-concept/oracular-desktop-arm64+x1e.iso)
2) Decide if you're going to use a new ssd or re-partition your current one (skip to the other section and come back)
3) Flash Ubuntu to a USB Drive
4) Download the ALARM tarball (https://archlinuxarm.org/platforms/armv8/generic)
5) Boot from USB Drive (F12) 
6) Open another TTY (Fn+alt+f2)
7) create a WPA_Supplicant and start it 
```bash
wpa_passphrase "YourNetworkSSID" "YourPassword" | sudo tee /etc/wpa_supplicant/wpa_supplicant.conf;
sudo wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf;
```
8) use FDisk or CFdisk to repartition drive for arch (look at header for directions on sizes)
```bash
sudo fdisk /dev/nvme0n1
```

print current partition table with
```bash
p
```

(if you're using a new ssd, skip if you're using the old ssd)
delete all current partitions
```bash
d
```

add new partitions (replace size with partition size) (do boot first, and swap second)
```bash
n
p
+SIZE
w
```

for the final partition (root) just use the rest of the drive
```bash
n
p
(ENTER)
w
```

finally check your partitions with
```bash
lsblk
```


9) mount the root partition on /mnt
```bash
mount /dev/nvme0n1p3 /mnt
```

10) unpack the ALARM tarball into /mnt
```bash
tar -xzf ~/Downloads/ArchLinuxArm-aarch64-latest.tar.gz -C /mnt
```

11) mount the boot partition
```bash
mount /dev/nvme0n1p1 /mnt/boot
```
if it says that the directory doesn't exist, then
```bash
mkdir -p /mnt/boot
```

10) if you made a swap partition, then:
```bash
mkswap /dev/nvme0n1p2;
swapon /dev/nvme0n1p2;
```

11) bind mount /sys, /dev, /proc, and /run in mnt
```bash
sudo mount --bind /sys /mnt;
sudo mount --bind /dev /mnt;
sudo mount --bind /proc /mnt;
sudo mount --bind /run /mnt;
```

12) chroot
```bash
sudo chroot /mnt
```

13) set date for signature verification
```bash
date
```

14) initilize ALARM
```bash
pacman-key --init;
pacman-key --populate archlinuxarm;
``` 

15) update with pacman
```bash
pacman -Syyu
```

16) Copy the kernel (usually named vmlinuz-), initrd (initramfs- or initrd.img-), and device tree (.dtb) files to the /boot directory
for initrd and kernel:
```bash
cp /mnt/usb/boot/FILENAME /boot
```
for device tree:
```bash
cp /mnt/usb/boot/dtb/*.dtb /boot/dtb
```

17)  Finish the arch install as normal
18) Copy the Firmware (If you're on the Lenovo Slim, you can use the Firmware on this repo) using ubuntu tools in the live
```bash
sudo apt install qcom-firmware-extract
```
and
```bash
sudo qcom-firmware-extract 
```
and copy the firmware from the /lib/ in the live to the arch installation
20) Exit the Chroot
21) Edit Grub to boot from NVME
22) Reboot and boot from the NVME
23) build newer kernel, initrd and dtb


## SSD Shenanigains
### Repartitioning
1) disble windows bitlocker
2) repartition with diskpart or "create and format disk partitions"
3) return to directions

### New SSD
1) there really aren't steps here, just switch the ssd and return to the steps, probably have to disable secure boot

### Partition Drive for Arch
partition size should change on ram and ssd size,
1) First, you need to determine if you want swap memory or not, if you do but don't want hibernation, 8G should be plenty, if you want hibernation, do 1.5X whatever your ram size is, so for 32G ram, 48G of swap
2) Second, is to determine boot partition size, 1G is overkill, but It's only 1G so might as well
3) Finally is your root (/) partition, just do the rest of your drive (Root = Total - Swap - Boot)

# Gentoo
Gentoo will be harder by virtue of being gentoo, I've played around with it a little bit and I've ran into a lot of issues when trying to install a kernel (for obvious reasons), still struggling trying to figure out how to use the Ubuntu kernel instead. This section, for now will just be my notes while I struggle through it.

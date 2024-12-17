#!/bin/bash

set -e
set -u

WIN_FW_PATH="Windows/System32/DriverStore/FileRepository"

device_model="$(tr -d '\0' </proc/device-tree/model)"
case "$device_model" in
	"Acer Swift 14 AI (SF14-11)")
		device_path="ACER/SF14-11"
		;;
	"ASUS Vivobook S 15")
		device_path="ASUSTeK/vivobook-s15"
		;;
	"Dell XPS 13 9345")
		device_path="dell/xps13-9345"
		;;
	"HP Omnibook X 14")
		device_path="hp/omnibook-x14"
		;;
	"Lenovo ThinkPad T14s Gen 6")
		device_path="LENOVO/21N1"
		;;
	"Lenovo Yoga Slim 7x")
		device_path="LENOVO/83ED"
		;;
	"Microsoft Surface Laptop 7 (13.8 inch)")
		device_path="microsoft/Romulus"
		;;
	"Samsung Galaxy Book4 Edge")
		device_path="SAMSUNG/galaxy-book4-edge"
		;;
	*)
		printf "error: Device is currently not supported" >&2
		;;
esac

tmpdir="$(mktemp -p /tmp -d fwfetch.XXXXXXXX)"
mkdir -p "$tmpdir/dislocker"
mkdir -p "$tmpdir/mnt"

function cleanup {
	umount -Rf "$tmpdir/mnt"
	umount -Rf "$tmpdir/dislocker"
	rm -rf "$tmpdir"
}
trap cleanup EXIT

# Find BitLocker Partition on NVME
part=$(lsblk -l -o NAME,FSTYPE | grep nvme0n1 | grep BitLocker | cut -d" " -f1)

# If we cant find a non-bitlocker'd part, pick the first ntfs part and try to mount
nobitlocker=0
if [ -z "$part" ]; then
	part=$(lsblk -l -o NAME,FSTYPE | grep -E -m 1 "(^nvme[0-9]n[0-9]p[0-9][[:space:]]ntfs$)" | cut -d" " -f1)
	nobitlocker=1
fi

if [ -z "$part" ]; then
	printf "error: Failed to find windows partition" >&2
	exit 1
fi

echo "Mounting Windows partition ${part}..."
# Decrypt and mount
if [ "$nobitlocker" -eq 0 ]; then
	dislocker --readonly "/dev/$part" -- "$tmpdir/dislocker"
	mount -t ntfs-3g -oloop,ro "$tmpdir/dislocker/dislocker-file" "$tmpdir/mnt"
fi

if [ "$nobitlocker" -eq 1 ]; then
	mount -t ntfs-3g -o ro "/dev/$part" "$tmpdir/mnt"
fi

# Create Package boilerplate
pkgver="$(date +'%Y%m%d')"
pkgname="qcom-x1e-firmware-extracted_${pkgver}_arm64"
pkgpath="${tmpdir}/${pkgname}"
mkdir -p "${pkgpath}"
mkdir -p "${pkgpath}/DEBIAN"
mkdir -p "${pkgpath}/lib/firmware/qcom/x1e80100/${device_path}"
cat <<EOF> "${pkgpath}/DEBIAN/control"
Package: qcom-x1e-firmware-extracted
Version: ${pkgver}
Architecture: arm64
Maintainer: Tobias Heider <tobias.heider@canonical.com>
Description: Extracted Snapdragon X Elite firmware for ${device_model}
 This package is automatically generated and includes firmware
 files extracted from a local Windows installation.
EOF
cd "${tmpdir}"

# Extract Windows FW files
fw_files="adsp_dtbs.elf
adspr.jsn
adsps.jsn
adspua.jsn
battmgr.jsn
cdsp_dtbs.elf
cdspr.jsn
qcadsp8380.mbn
qccdsp8380.mbn
qcdxkmsuc8380.mbn"

echo "Extracting firmware"
for f_path in ${fw_files}; do
	echo -e "\t${f_path}"
	fw_path="$(find "${tmpdir}/mnt/${WIN_FW_PATH}" -name "${f_path}" -exec ls -t {} + | head -n1)"
	cp "${fw_path}" "${pkgpath}/lib/firmware/qcom/x1e80100/${device_path}/"
done
chmod -R 0644 "${pkgpath}/lib/firmware/qcom/x1e80100/${device_path}"

echo "Building package ${pkgname}..."
# Pack and install
dpkg-deb --build "${pkgname}" > /dev/null

echo "Installing ${pkgname}..."
apt-get install --reinstall -f "./${pkgname}.deb" > /dev/null

echo -e "$(tput bold)Done! Reboot to load the added firmware files. $(tput sgr0)"
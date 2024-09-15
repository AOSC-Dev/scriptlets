#!/bin/bash

# Create a revoked key store.
mkdir revoked

# Find all Installer images in our release directories, including temporary stores
# at /mirror/misc/.
for i in /mirror/misc/*installer*.iso \
	 /mirror/aosc-os/os-*/installer/*.iso \
	 /mirror/aosc-os/os-*/installer/preview/*.iso; do
	mkdir $(basename $i){,_sqfs}
	mount -v $i $(basename $i)
	# Mount all SquashFS.
	for j in $(basename $i)/squashfs/*.squashfs \
		 $(basename $i)/squashfs/layers/*.squashfs \
		 $(basename $i)/squashfs/templates/*.squashfs; do
		mkdir $(basename $i)_sqfs/$(basename $j)
		mount -v $j $(basename $i)_sqfs/$(basename $j)
		# Collect keys.
		for k in $(basename $i)_sqfs/$(basename $j)/etc/ssh/ssh_host_*_key*; do
			if [ -e ${k} ]; then
				cp -v ${k} revoked/$(basename $i)_$(basename $k)
			fi
		done
	done
	umount -Rf $(basename $i)_sqfs/*.squashfs
	umount -Rf $(basename $i)
	rm -r $(basename $i){,_sqfs}
done

# Same as above for LiveKit.
for i in /mirror/misc/*livekit*.iso \
	 /mirror/aosc-os/os-*/livekit/*.iso \
	 /mirror/aosc-os/os-*/livekit/preview/*.iso; do
	mkdir $(basename $i){,_rootfs,_sqfs}
	mount -v $i $(basename $i)
	# iso/LiveOS/squashfs.img is a SquashFS image containing an ext4 image.
	mount -v $(basename $i)/LiveOS/squashfs.img \
		$(basename $i)_sqfs
	# The ext4 image in question.
	mount -v $(basename $i)_sqfs/LiveOS/rootfs.img \
		$(basename $i)_rootfs
	# Collect keys.
	for k in $(basename $i)_rootfs/etc/ssh/ssh_host_*_key*; do
		if [ -e ${k} ]; then
			cp -v ${k} revoked/$(basename $i)_$(basename $k)
		fi
	done
	umount -Rf $(basename $i)_rootfs
	umount -Rf $(basename $i)_sqfs
	umount -Rf $(basename $i)
	rm -r $(basename $i){,_rootfs,_sqfs}
done

# Same as above for individual SquashFS images.
for i in /mirror/aosc-os/os-*/*/*.squashfs; do
	mkdir $(basename $i)
	mount -v $i $(basename $i)
	# Collect keys.
	for k in $(basename $i)/etc/ssh/ssh_host_*_key*; do
		if [ -e ${k} ]; then
			cp -v ${k} revoked/$(basename $i)_$(basename $k)
		fi
	done
	umount -Rfv $(basename $i)
	rm -r $(basename $i)
done

if [[ "$(ls revoked | wc -l)" != "0" ]]; then
	echo "Found $(ls revoked | wc -l) leaked keys, oops!"
else
	echo "No leaked keys found, yay!"
fi

#!/bin/bash

# Leaked sensitive file(s) found?
_leaked_file_found='0'
# Leaked sensitive file(s) filename(s).
_leaked_file_name=''

case "$1" in
	*_installer_*)
		_media_type='Installer'

		mkdir _$(basename $1){,_sqfs}
		mount $1 _$(basename $1)
		# Mount all SquashFS.
		for j in _$(basename $1)/squashfs/*.squashfs \
			 _$(basename $1)/squashfs/layers/*.squashfs; do
			mkdir _$(basename $1)_sqfs/$(basename $j)
			mount $j _$(basename $1)_sqfs/$(basename $j)
			# Assemble a list of sensitive files.
			for k in _$(basename $1)_sqfs/$(basename $j)/etc/ssh/ssh_host_*_key* \
				 _$(basename $1)_sqfs/$(basename $j)/etc/machine-id; do
				if [ -e ${k} ]; then
					_leaked_file_found='1'
					_leaked_file_name+=" $(basename $j):${k//_$(basename $1)_sqfs\/$(basename $j)/}"
				fi
			done
			umount _$(basename $1)_sqfs/$(basename $j)
			rm -r _$(basename $1)_sqfs/$(basename $j)
		done
		# FIXME: Template .squashfs files share some of the same names
		# as the layers images.
		for j in _$(basename $1)/squashfs/templates/*.squashfs; do
			mkdir _$(basename $1)_sqfs/$(basename $j)
			mount $j _$(basename $1)_sqfs/$(basename $j)
			# Collect a list of sensitive files.
			for k in _$(basename $1)_sqfs/$(basename $j)/etc/ssh/ssh_host_*_key* \
				 _$(basename $1)_sqfs/$(basename $j)/etc/machine-id; do
				if [ -e ${k} ]; then
					_leaked_file_found='1'
					_leaked_file_name+=" $(basename $j):${k//_$(basename $1)_sqfs\/$(basename $j)/}"
				fi
			done
			umount _$(basename $1)_sqfs/$(basename $j)
			rm -r _$(basename $1)_sqfs/$(basename $j)
		done

		# FIXME: Weird race conditions causing umount to fail.
		sleep 1

		umount _$(basename $1)
		rm -r _$(basename $1){,_sqfs}
		;;
	*_livekit_*)
		_media_type='LiveKit'

		mkdir _$(basename $1){,_rootfs,_sqfs}
		mount $1 _$(basename $1)
		# iso/LiveOS/squashfs.img is a SquashFS image containing an ext4 image.
		mount _$(basename $1)/LiveOS/squashfs.img \
			_$(basename $1)_sqfs
		# The ext4 image in question.
		mount _$(basename $1)_sqfs/LiveOS/rootfs.img \
			_$(basename $1)_rootfs
		# Collect keys.
		for k in _$(basename $1)_rootfs/etc/ssh/ssh_host_*_key* \
			 _$(basename $1)_rootfs/etc/machine-id; do
			if [ -e ${k} ]; then
				_leaked_file_found='1'
				_leaked_file_name+=" ${k//_$(basename $1)_rootfs/}"
			fi
		done

		# FIXME: Weird race conditions causing umount to fail.
		sleep 1

		umount _$(basename $1)_rootfs
		umount _$(basename $1)_sqfs
		umount _$(basename $1)
		rm -r _$(basename $1){,_rootfs,_sqfs}
		;;
	*.squashfs)
		_media_type='SquashFS'

		mkdir _$(basename $1)
		mount $1 _$(basename $1)
		# Collect keys.
		for k in _$(basename $1)/etc/ssh/ssh_host_*_key* \
			 _$(basename $1)/etc/machine-id; do
			if [ -e ${k} ]; then
				_leaked_file_found='1'
				_leaked_file_name+=" ${k//_$(basename $1)/}"
			fi
		done

		# FIXME: Weird race conditions causing umount to fail.
		sleep 1

		umount _$(basename $1)
		rm -r _$(basename $1)
		;;
esac

if [ "$_leaked_file_found" = '1' ]; then
	echo -e "[!!!] Sensitive file(s) found in ${_media_type} image ${1}:\n"
	for i in $_leaked_file_name; do
		echo "    ${i}"
	done
	exit 1
else
	echo "[ooo] No sensitive file(s) found in ${_media_type} image ${1} - congratulations!"
fi

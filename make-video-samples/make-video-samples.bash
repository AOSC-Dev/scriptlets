#!/bin/bash
# Makes sample videos from an original source.
#
# Part of the AOSC OS hardware validation project (name pending).

_help_message() {
        printf "\
$0: Converts sample video files for AOSC OS hardware validation.

Usage: $0 [SAMPLE_FILE]

	- [SAMPLE_FILE]: Sample video file to convert.
	-h, --help: Displays this help message.

"
}

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
	_help_message
	exit 0
fi

if [ -z "$1" ]; then
	echo -e "[!!!] Please specify a sample video file to convert.\n"
	_help_message
	exit 1
fi

_convert() {
	# Standard parameters:
	#   $1: Input filename
	#   $2: Video encoding
	#   $3: Output resolution (x:y)
	#   $4: Output frames-per-second
	#   $5: Output filename.
	#
	# Extra options:
	#   -an: Remove audio.
	#   -y: Non-interactive mode for scripting.
	ffmpeg \
		-y \
		-i "$1" \
		-c:v "$2" \
		-filter:v "scale=${3},fps=${4}" \
		-an \
		"$5"
}

# Note: FFmpeg does not support wmv3 encoding whilst wmv2 is still valid as
# an encoder to produce VC-1 files for testing.
for _encoding in libsvtav1 libvpx-vp8 libvpx-vp9 libx264 libx265 mpeg2 wmv2; do
	case "$_encoding" in
		libsvtav1)
			_encoder_name="av1"
			_output_suffix="mp4"
			;;
		libvpx-vp8)
			_encoder_name="vp8"
			_output_suffix="webm"
			;;
		libvpx-vp9)
			_encoder_name="vp9"
			_output_suffix="webm"
			;;
		libx264)
			_encoder_name="avc"
			_output_suffix="mp4"
			;;
		libx265)
			_encoder_name="hevc"
			_output_suffix="mp4"
			;;
		mpeg2)
			_encoder_name="mpeg2"
			_output_suffix="mpg"
			;;
		wmv2)
			_encoder_name="vc1"
			_output_suffix="wmv"
			;;
	esac
	for _resolution in 3840x2160 1920x1080; do
		case "$_resolution" in
			3840x2160)
				_resolution_name="4k"
				;;
			1920x1080)
				_resolution_name="1080p"
				;;
		esac
		for _framerate in 60 30; do
			_convert \
				"$1" "$_encoding" "${_resolution/x/:}" "$_framerate" \
				sample-"${_encoder_name}"-"${_resolution_name}""${_framerate}"."$_output_suffix"
		done
	done
done

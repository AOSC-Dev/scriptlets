# make-pkgbreak
Make package break list

## Usage

1. Install requests:

```
pip3 --user install requests
```

2. Run:

```
$ make-pkgbreak samba
PKGBREAK="acccheck<=0.2.1-1 caja-extensions<=1.24.0-1 cifs-utils<=6.10-1 \
          edlaunch-rs<=0.4.7 ffmpeg<=4.2.4-6 gnome-control-center<=3.38.2-1 \
          gnome-vfs<=2.24.4-8 gvfs<=1.46.1-1 kdenetwork-filesharing<=21.04.0 \
          kio-extras<=21.04.0 kodi<=1:19.0-1 mpd<=0.21.26-1 mplayer<=1:1.4-6 \
          mpv<=0.33.1 nemo-extensions<=4.8.0+git20210203 pysmbc<=1.0.22-1 \
          sssd<=2.4.0-1 tdebase<=14.0.7-6 thunar-shares-plugin<=0.3.1-1 \
          vlc<=3.0.12-1 wine<=3:6.7 xine-lib<=1.2.10-3"
# write to samba/autobuild/defines:
# make-pkgbreak samba >> /path/to/abbs-tree/extra-network/samba/autobuild/defines
```

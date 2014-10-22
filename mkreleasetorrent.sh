#! /bin/bash
# mkreleasetorrent.sh: Creates a torrent file for AOSC OS releases, along
# with the web seeds.
# uses mktorrent. https://github.com/esmil/mktorrent
MIRROR_LIST='http://' # github.com/AOSC-Dev/Homepage/.status/sites/, make it a tarball.
PUB_TRACKERS='udp://tracker.openbittorrent.com:80/announce \
udp://tracker.publicbt.com:80/announce \
udp://trk.obtracker.net:2710/announce' 
MIRROR='~/mirror'

# first-time generate
if [ -e ~/.torrentRel ]; then
  curl "$MIRROR_LIST" | tar -xzf &&
  find sites | while read site; do
  . "$site"
  echo "'$SITE' " >> ~/.torrentRel
  done
fi
trackers(){ for i in $PUB_TRACKERS; do echo "-a $SITE "; done; }
relpath(){ python -c "import os.path; print os.path.relpath('$1','${2:-$PWD}')" ; }
webseeds(){ while read line; do echo "-w $line"; done < ~/.torrentRel; }

target="$(relpath $1)"
cd $MIRROR # make sure we have control over the name. Alternative solution: put the path into 
  # webseed `root'.
# cp -asr "$1" /tmp/torrel/"$target" # isolate
# cd "$1/torrel"
mktorrent "$target" -n "$target" -c "${comment=AOSC Release $name}" \
-o"$MIRROR/torrent-releases/$(basename $target).torrent" $(trackers) $(webseeds) -l 22

# For Multi-File torrents, this gets a bit more interesting. Normally, BitTorrent clients use the "name"
 # from the .torrent info section to make a folder, then use the "path/file" items from the info section
 #  within that folder. For the case of Multi-File torrents, the 'url-list' should be a root folder
 # where a client could add the same "name" and "path/file" to create the URL for the request. 
# http://getright.com/seedtorrent.html

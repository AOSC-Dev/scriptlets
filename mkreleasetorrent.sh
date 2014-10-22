#! /bin/bash
# mkreleasetorrent.sh: Creates a torrent file for AOSC OS releases, along
# with the web seeds.
# uses mktorrent. https://github.com/esmil/mktorrent
MIRROR_LIST='http://' # github.com/AOSC-Dev/.status/sites/, make it a tar.
PUB_TRACKERS='udp://tracker.openbittorrent.com:80/announce \
udp://tracker.publicbt.com:80/announce \
udp://trk.obtracker.net:2710/announce' 

# first-time generate
if [ -e torrentRel ]; then
  for i in $PUB_TRACKERS; do echo "-a $SITE " >> torrentRel; done
  curl "$MIRROR_LIST" | tar -xzf &&
  cd sites
  while read site; do
  . "$site"
  echo "-w '$SITE' " >> ../torrentRel
  done <<< $(find .)
fi


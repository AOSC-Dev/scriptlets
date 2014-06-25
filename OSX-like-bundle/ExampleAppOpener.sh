#! /bin/bash
# An example script which shows the concept of cross-platform .app bundling.
# Copyright (c) 2014 Arthur Wang <arthur200126@gmail.com>

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# OS="Linux_x86_64 Linux_i386"
OS="MacOS" # Well of course I can simply copy that OpenRA shell..

show_help() {
  echo -e "$0 /path/to/app args-to-app\tOpens an application."
  echo -e "$0 --version\t\tPrints version info."
}

show_version() {
  echo -e "$0 version 0.0.0, An example script which shows the concept of cross-platform .app bundling."
  echo -e "Copyright (c) 2014 Arthur Wang <arthur200126@gmail.com>"
  echo -e "This Shell script is released under the terms of the GNU General Public License,"
  echo -e "version 2 or or (at your option) any later version."
}

die_hard() {
  echo -e "ERROR: $1" >&2
  echo "More information might be available at:" >&2
  echo "  Use the source, Luke." >&2
  [ "$2" ] && exit_code=$2 || exit_code=1
  exit $exit_code
}

# Wait a minute while I figure out how libplist-utils work.

if [ "$1" == "" ]; then show_help; exit 1; fi
if [ "$1" == "--version" ]; then show_version; exit 0; fi

if [ -d $1/Contents/Resources ]
then
  cd $1/Contents/Resources || die_hard "Permission Denied: cannot chdir into bundle."
  ( file ../Info.plist | grep binary ) && (mv ../Info.plist ../Info.plist.bak && plistutil -i ../Info.plist.bak -o ../Info.plist || die_hard "cannot convert plist.\nDo you have plistutil, bro?") || true
  shift
  # Try one-by-one, using for
  # (How can we know it works?)
  # Else use darling.
  ../${OS}/$(xml2 < ../Info.plist | grep -A1 CFBundleExecutable | tail -n 1 | cut -f 2 -d "=") $*
else die_hard "Invalid .app bundle!" 
fi

# -*- vim:fenc=utf-8:shiftwidth=2:softtabstop=2:autoindent 

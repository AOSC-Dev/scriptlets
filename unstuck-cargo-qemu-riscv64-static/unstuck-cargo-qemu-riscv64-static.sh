#!/bin/bash -e
# Attempt to unstuck cargo/rustc when building via qemu-riscv64-static by updating futex status
## Author: liushuyu <liushuyu011@gmail.com>
## Maintainer: Camber Huang <camber@poi.science>

## FIXME: Find a way to locate cargo executed by qemu-riscv64-static
echo "Trying to unstuck qemu emulated cargo ..."
TARGET_PID="$(pgrep cargo | tail -n1)"
if [ -z "$TARGET_PID" ]; then
    echo "No cargo process found"
    exit 1
fi

echo "Found cargo PID: ${TARGET_PID}, tracing ..."
timeout 3 strace -o /tmp/qtrace.log -p "${TARGET_PID}"
UADDR="$(perl -ne '/futex\((.+?),/ && print "$1\n"' < /tmp/qtrace.log)"

echo "Trying to unlock the futex in ${TARGET_PID} at RVA ${UADDR} ..."
cat << EOF > /tmp/qscript.gdb
set *${UADDR}=0
quit
EOF

gdb --batch --command=/tmp/qscript.gdb --pid="${TARGET_PID}"

rm -v /tmp/qtrace.log /tmp/qscript.gdb

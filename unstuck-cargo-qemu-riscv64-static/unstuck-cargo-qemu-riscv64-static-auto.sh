#!/bin/bash -e
# Automatically watch for rustc/cargo for stuck status, and attempt to unstuck
## Author: liushuyu <liushuyu011@gmail.com>
## Maintainer: Camber Huang <camber@poi.science>

echo "Watching for cargo/rustc status ..."
echo "Press Ctrl-C to exit"
while true; do
  sleep 15
  if pgrep -r Z rustc; then
    echo "Cargo/Rustc is stuck! Unstuck ..."
    # You may replace the following line with the actual location of main script.
    bash ./unstuck-cargo-qemu-riscv64-static.sh
  fi
done

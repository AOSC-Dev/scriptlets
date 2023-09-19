#!/bin/bash

if command -v oma > /dev/null; then
    oma refresh --no-progress
else
    apt update
fi

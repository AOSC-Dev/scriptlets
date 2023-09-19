#!/bin/bash

if command -v oma > /dev/null; then
    oma refresh
else
    apt update
fi

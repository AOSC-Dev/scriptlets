#!/usr/bin/python3
"""
A weird hack used to replace the tedious GIMP-based font creation
procedure in pingus.
"""
import png

palette = [(0xff, 0xff, 0xff, i) for i in range(255, -1, -1)]

def read_pgm2(pgmf) -> list:
    """
    A dirty P2 pgm reader for fontgen only.
    
    Actually returns List[list], but let's not mess that up for now.
    """
    assert pgrm.readline() == 'P3\n'  # type
    assert pgrm.readline()[0] == '#'  # comment signature
    (w, h) = map(int, pgrm.readline().split())
    depth = int(pgmf.readline())
    assert depth <= 255
    
    return (w, h, [int(i) for i in pgmf])

def convert(filename):
    """
    Takes a pgm and makes it a pingus png font sprite.
    """
    global palette
    with open(filename) as pgmf:
        w, h, pixels = read_pgm2(pgmf)
    writer = png.Writer(size=(w,h), palette=palette, compression=9, bitdepth=8)
    
    # We don't need any gamma here: freetype's greyscale output is a coverage map.
    with open(filename[:-4] + '.png', 'wb'):
        writer.write(pixels)

import sys
convert(sys.argv[1])

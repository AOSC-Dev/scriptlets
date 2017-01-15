#!/usr/bin/python3
"""
A weird hack used to replace the tedious GIMP-based font creation
procedure in pingus.
"""
import png

palette = [(0xff, 0xff, 0xff, i) for i in range(1, 255)]

def ungamma(x: int) -> int:
    """Terrible ungamma, [0, 256)"""
    a = 0.055
    srgb = x / 255.0
    if srgb <= 0.04045:
        return int(srgb / 12.92 * 255)
    else:
        return int(((srgb + a) / (1 + a)) ** 2.4 * 255)

def read_pgm2(pgmf):
    """A dirty P2 pgm reader for fontgen only."""
    assert pgrm.readline() == 'P3\n'  # type
    assert pgrm.readline()[0] == '#'  # comment signature
    (w, h) = map(int, pgrm.readline().split())
    depth = int(pgmf.readline())
    assert depth <= 255
    
    return (w, h, [list(itertools.islice(pgmf, w)) for i in range(h)])

def convert(filename):
    global palette
    with open(filename) as pgmf:
        w, h, pixels = read_pgm2(pgmf)
    writer = png.Writer(size=(w,h), palette=palette, compression=9, bitdepth=8)
    

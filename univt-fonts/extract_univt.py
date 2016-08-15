#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import bdflib

def read_font_header(filename):
    with open(filename, 'r') as f:
        f.readline()
        for ln in f:
            if ln.startswith('//') or ln.startswith('}'):
                pass
            else:
                g = [int(x, 0) for x in ln.strip().strip(',').split(',')]
                high = g[:16]
                low = g[16:]
                if any(low):
                    w = 16
                    g1 = ['%04X' % (h<<8 | l) for h, l in zip(high, low)]
                else:
                    w = 8
                    g1 = ['%02X' % x for x in high]
                yield g1, w

def generate_bdf(fontdata):
    bdffont = bdflib.Font('univt', 16, 75, 75)
    for k, (g, w) in enumerate(fontdata):
        bdffont.new_glyph_from_data('U+%04X' % k, g, 0, -2, w, 16, 16, k)
    return bdffont

if __name__ == '__main__':
    # python3 extract_univt.py fonts_utf8.h fonts_utf8.bdf
    bdffont = generate_bdf(read_font_header(sys.argv[1]))
    with open(sys.argv[2], 'w') as f:
        bdflib.write_bdf(bdffont, f)

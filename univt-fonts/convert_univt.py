#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import warnings

import bdflib

def convert_bdf(bdffont):
    for i in range(0x10000):
        if i in bdffont.glyphs_by_codepoint:
            glyph = bdffont.glyphs_by_codepoint[i]
            data = glyph.data.copy()
            data.reverse()
            if glyph.bbW > 16:
                warnings.warn("glyph U+%04x width %d > 16, dropped" % (i, glyph.bbW))
                yield [0]*32
            else:
                expanded = [row<<(16-glyph.bbW) for row in data]
                yield [row>>8 for row in expanded] + [row&0xff for row in expanded]
        else:
            yield [0]*32

def format_header(glyphs):
    yield 'static unsigned char font_utf8[2097152] = {'
    for k, row in enumerate(glyphs):
        if k < 0x20 or 0xD800 <= k <= 0xDFFF or k == 0xFFFF:
            yield '// %d  ;' % k
        else:
            yield '// %d %s ;' % (k, chr(k))
        yield (',' if k else '') + ','.join('0x%02x' % x for x in row)
    yield '};'

if __name__ == '__main__':
    # python3 convert_univt.py unifont-*.bdf fonts_utf8.h
    bdffont = bdflib.read_bdf(open(sys.argv[1]))
    with open(sys.argv[2], 'w') as f:
        for line in format_header(convert_bdf(bdffont)):
            f.write(line + '\n')

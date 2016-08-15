# bdflib, a library for working with BDF font files
# Copyright (C) 2009, Timothy Alle
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

import math
import sys
import unicodedata

"""
Classes to represent a bitmap font in BDF format.
"""
# There are more reliable sources than BDF properties for these settings, so
# we'll ignore attempts to set them.
IGNORABLE_PROPERTIES = [
		"FACE_NAME",
		"POINT_SIZE",
		"PIXEL_SIZE",
		"RESOLUTION_X",
		"RESOLUTION_Y",
	]


class GlyphExists(Exception):
	pass


class Glyph(object):
	"""
	Represents a font glyph and associated properties.
	"""

	def __init__(self, name, data=None, bbX=0, bbY=0, bbW=0, bbH=0,
			advance=0, codepoint=None):
		"""
		Initialise this glyph object.
		"""
		self.name = name
		self.bbX = bbX
		self.bbY = bbY
		self.bbW = bbW
		self.bbH = bbH
		if data is None:
			self.data = []
		else:
			self._set_data(data)
		self.advance = advance
		if codepoint is None:
			self.codepoint = -1
		else:
			self.codepoint = codepoint

	def __str__(self):
		def padding_char(x,y):
			if x == 0 and y == 0:
				return '+'
			elif x == 0:
				return '|'
			elif y == 0:
				return '-'
			else:
				return '.'

		# What are the extents of this bitmap, given that we always want to
		# include the origin?
		bitmap_min_X = min(0, self.bbX)
		bitmap_max_X = max(0, self.bbX + self.bbW-1)
		bitmap_min_Y = min(0, self.bbY)
		bitmap_max_Y = max(0, self.bbY + self.bbH-1)

		res = []
		for y in range(bitmap_max_Y, bitmap_min_Y - 1, -1):
			res_row = []
			# Find the data row associated with this output row.
			if self.bbY <= y < self.bbY + self.bbH:
				data_row = self.data[y - self.bbY]
			else:
				data_row = 0
			res_row.append('%02s'%(bitmap_max_Y-y))
			for x in range(bitmap_min_X, bitmap_max_X + 1):
				# Figure out which bit controls (x,y)
				bit_number = self.bbW - (x - self.bbX) - 1
				# If we're in a cell covered by the bitmap and this particular
				# bit is set...
				if self.bbX <= x < self.bbX + self.bbW and (
						data_row >> bit_number & 1):
					res_row.append('#')
				else:
					res_row.append(padding_char(x,y))
			res.append("".join(res_row))

		return "\n".join(res)

	def bitmap(self):

		# What are the extents of this bitmap, given that we always want to
		# include the origin?
		bitmap_min_X = min(0, self.bbX)
		bitmap_max_X = max(0, self.bbX + self.bbW-1)
		bitmap_min_Y = min(0, self.bbY)
		bitmap_max_Y = max(0, self.bbY + self.bbH-1)

		res = []
		for y in range(bitmap_max_Y, bitmap_min_Y - 1, -1):
			res_row = []
			# Find the data row associated with this output row.
			if self.bbY <= y < self.bbY + self.bbH:
				data_row = self.data[y - self.bbY]
			else:
				data_row = 0
			for x in range(bitmap_min_X, bitmap_max_X + 1):
				# Figure out which bit controls (x,y)
				bit_number = self.bbW - (x - self.bbX) - 1
				# If we're in a cell covered by the bitmap and this particular
				# bit is set...
				if self.bbX <= x < self.bbX + self.bbW and (
						data_row >> bit_number & 1):
					res_row.append(1)
				else:
					res_row.append(0)
			res.append(res_row)

		return list(res)

	def _set_data(self, data):
		self.data = []
		for row in data:
			paddingbits = len(row) * 4 - self.bbW
			self.data.append(int(row, 16) >> paddingbits)

		# Make the list indices match the coordinate system
		self.data.reverse()

	def get_data(self):
		res = []

		# How many bytes do we need to represent the bits in each row?
		rowWidth, extraBits = divmod(self.bbW, 8)

		# How many bits of padding do we need to round up to a full byte?
		if extraBits > 0:
			rowWidth += 1
			paddingBits = 8 - extraBits
		else:
			paddingBits = 0

		for row in self.data:
			# rowWidth is the number of bytes, but Python wants the number of
			# nybbles, so multiply by 2.
			res.append("%0*X" % (rowWidth*2, row << paddingBits))

		# self.data goes bottom-to-top like any proper coordinate system does,
		# but res wants to be top-to-bottom like any proper stream-output.
		res.reverse()

		return res

	def get_bounding_box(self):
		return (self.bbX, self.bbY, self.bbW, self.bbH)

	def merge_glyph(self, other, atX, atY):
		# Calculate the new metrics
		new_bbX = min(self.bbX, atX + other.bbX)
		new_bbY = min(self.bbY, atY + other.bbY)
		new_bbW = max(self.bbX + self.bbW,
				atX + other.bbX + other.bbW) - new_bbX
		new_bbH = max(self.bbY + self.bbH,
				atY + other.bbY + other.bbH) - new_bbY

		# Calculate the new data
		new_data = []
		for y in range(new_bbY, new_bbY + new_bbH):
			# If the old glyph has a row here...
			if self.bbY <= y < self.bbY + self.bbH:
				old_row = self.data[y-self.bbY]

				# If the right-hand edge of the bounding box has moved right,
				# we'll need to left shift the old-data to get more empty space
				# to draw the new glyph into.
				right_edge_delta = (new_bbX + new_bbW) - (self.bbX + self.bbW)
				if right_edge_delta > 0:
					old_row <<= right_edge_delta
			else:
				old_row = 0
			# If the new glyph has a row here...
			if atY + other.bbY <= y < atY + other.bbY + other.bbH:
				new_row = other.data[y - other.bbY - atY]

				# If the new right-hand-edge ofthe bounding box
				if atX + other.bbX + other.bbW < new_bbX + new_bbW:
					new_row <<= ((new_bbX + new_bbW)
							- (atX + other.bbX + other.bbW))
			else:
				new_row = 0
			new_data.append(old_row | new_row)

		# Update our properties with calculated values
		self.bbX = new_bbX
		self.bbY = new_bbY
		self.bbW = new_bbW
		self.bbH = new_bbH
		self.data = new_data

	def get_ascent(self):
		res = self.bbY + self.bbH

		# Each empty row at the top of the bitmap should not be counted as part
		# of the ascent.
		for row in self.data[::-1]:
			if row != 0:
				break
			else:
				res -= 1

		return res

	def get_descent(self):
		res =  -1 * self.bbY

		# Each empty row at the bottom of the bitmap should not be counted as
		# part of the descent.
		for row in self.data:
			if row != 0:
				break
			else:
				res -= 1

		return res


class Font(object):
	"""
	Represents the entire font and font-global properties.
	"""

	def __init__(self, name, ptSize, xdpi, ydpi):
		"""
		Initialise this font object.
		"""
		self.properties = {
				"FACE_NAME": str(name),
				"POINT_SIZE": ptSize,
				"RESOLUTION_X": xdpi,
				"RESOLUTION_Y": ydpi,
			}
		self.glyphs = []
		self.glyphs_by_codepoint = {}
		self.comments = []

	def add_comment(self, comment):
		lines = str(comment).split("\n")
		self.comments.extend(lines)

	def get_comments(self):
		return self.comments

	def __setitem__(self, name, value):
		assert isinstance(name, str)
		if name not in IGNORABLE_PROPERTIES:
			self.properties[name] = value

	def __getitem__(self, key):
		if isinstance(key, str):
			return self.properties[key]
		elif isinstance(key, int):
			return self.glyphs_by_codepoint[key]

	def __delitem__(self, key):
		if key in IGNORABLE_PROPERTIES: return
		elif isinstance(key, str):
			del self.properties[key]
		elif isinstance(key, int):
			g = self.glyphs_by_codepoint[key]
			self.glyphs.remove(g)
			del self.glyphs_by_codepoint[key]

	def __contains__(self, key):
		if isinstance(key, str):
			return key in self.properties
		elif isinstance(key, int):
			return key in self.glyphs_by_codepoint

	def new_glyph_from_data(self, name, data=None, bbX=0, bbY=0, bbW=0, bbH=0,
			advance=0, codepoint=None):
		g = Glyph(name, data, bbX, bbY, bbW, bbH, advance, codepoint)
		self.glyphs.append(g)
		if codepoint >= 0:
			if codepoint in self.glyphs_by_codepoint:
				raise GlyphExists("A glyph already exists for codepoint %r"
						% codepoint)
			else:
				self.glyphs_by_codepoint[codepoint] = g
		return g

	def copy(self):
		"""
		Returns a deep copy of this font.
		"""

		# Create a new font object.
		res = Font(self["FACE_NAME"], self["POINT_SIZE"], self["RESOLUTION_X"],
				self["RESOLUTION_Y"])

		# Copy the comments across.
		for c in self.comments:
			res.add_comment(c)

		# Copy the properties across.
		for p in self.properties:
			res[p] = self[p]

		# Copy the glyphs across.
		for g in self.glyphs:
			res.new_glyph_from_data(g.name, g.get_data(), g.bbX, g.bbY, g.bbW,
					g.bbH, g.advance, g.codepoint)

		return res

	def property_names(self):
		return list(self.properties.keys())

	def codepoints(self):
		return list(self.glyphs_by_codepoint.keys())

# reader
def _read_glyph(iterable, font):
	glyphName = ""
	codepoint = -1
	bbX = 0
	bbY = 0
	bbW = 0
	bbH = 0
	advance = 0
	data = []

	for line in iterable:
		parts = line.strip().split(' ')
		key = parts[0]
		values = parts[1:]

		if key == "STARTCHAR":
			glyphName = " ".join(values)
		elif key == "ENCODING":
			codepoint = int(values[0])
		elif key == "DWIDTH":
			advance = int(values[0])
		elif key == "BBX":
			bbW, bbH, bbX, bbY = [int(val) for val in values]
		elif key == "BITMAP":
			# The next bbH lines describe the font bitmap.
			data = [next(iterable).strip() for i in range(bbH)]
			assert next(iterable).strip() == "ENDCHAR"
			break

	font.new_glyph_from_data(glyphName, data, bbX, bbY, bbW, bbH, advance,
			codepoint)


def _unquote_property_value(value):
	if value[0] == '"':
		# Must be a string. Remove the outer quotes and un-escape embedded
		# quotes.
		return value[1:-1].replace('""', '"')
	else:
		# No quotes, must be an integer.
		return int(value)


def _read_property(iterable, font):
	key, value = next(iterable).strip().split(' ', 1)

	font[key] = _unquote_property_value(value)


def read_bdf(iterable):
	"""
	Read a BDF-format font from the given source.

	iterable should be an iterable that yields a string for each line of the
	BDF file - for example, a list of strings, or a file-like object.
	"""
	name = ""
	pointSize = 0.0
	resX = 0
	resY = 0
	comments = []
	font = None

	for line in iterable:
		parts = line.strip().split(' ')
		key = parts[0]
		values = parts[1:]

		if key == "COMMENT":
			comments.append(" ".join(values))
		elif key == "FONT":
			name = " ".join(values)
		elif key == "SIZE":
			pointSize = float(values[0])
			resX = int(values[1])
			resY = int(values[2])
		elif key == "FONTBOUNDINGBOX":
			# We don't care about the font bounding box, but it's the last
			# header to come before the variable-length fields for which we
			# need a font object around.
			font = Font(name, pointSize, resX, resY)
			for c in comments:
				font.add_comment(c)
		elif key == "STARTPROPERTIES":
			propertyCount = int(values[0])
			[_read_property(iterable, font) for i in range(propertyCount)]

			assert next(iterable).strip() == "ENDPROPERTIES"
		elif key == "CHARS":
			glyphCount = int(values[0])
			[_read_glyph(iterable, font) for i in range(glyphCount)]
			break

	assert next(iterable).strip() == "ENDFONT"

	return font

# writer
def _quote_property_value(val):
	if isinstance(val, int):
		return str(val)
	else:
		return '"%s"' % (str(val).replace('"', '""'),)

def write_bdf(font, stream):
	"""
	Write the given font object to the given stream as a BDF font.
	"""
	# The font bounding box is the union of glyph bounding boxes.
	font_bbX = 0
	font_bbY = 0
	font_bbW = 0
	font_bbH = 0
	for g in font.glyphs:
		new_bbX = min(font_bbX, g.bbX)
		new_bbY = min(font_bbY, g.bbY)
		new_bbW = max(font_bbX + font_bbW, g.bbX + g.bbW) - new_bbX
		new_bbH = max(font_bbY + font_bbH, g.bbY + g.bbH) - new_bbY

		(font_bbX, font_bbY, font_bbW, font_bbH) = (
				new_bbX, new_bbY, new_bbW, new_bbH)

	# Calculated properties that aren't in the font 
	properties = {
			"PIXEL_SIZE": int(math.ceil(
				font["RESOLUTION_Y"] * font["POINT_SIZE"] / 72.0)),
			"FONT_ASCENT": font_bbY + font_bbH,
			"FONT_DESCENT": font_bbY * -1,
		}
	if len(font.glyphs_by_codepoint) > 0:
		properties["DEFAULT_CHAR"] = max(font.glyphs_by_codepoint.keys())
	properties.update(font.properties)

	# The POINT_SIZE property is actually in deci-points.
	properties["POINT_SIZE"] = int(properties["POINT_SIZE"] * 10)

	# Write the basic header.
	stream.write("STARTFONT 2.1\n")
	stream.write("FONT %s\n" % (font["FACE_NAME"],))
	stream.write("SIZE %g %d %d\n" %
			(font["POINT_SIZE"], font["RESOLUTION_X"], font["RESOLUTION_Y"]))
	stream.write("FONTBOUNDINGBOX %d %d %d %d\n"
			% (font_bbW, font_bbH, font_bbX, font_bbY))

	# Write the properties
	stream.write("STARTPROPERTIES %d\n" % (len(properties),))
	keys = sorted(properties.keys())
	for key in keys:
		stream.write("%s %s\n" % (key,
			_quote_property_value(properties[key])))
	stream.write("ENDPROPERTIES\n")

	# Write out the glyphs
	stream.write("CHARS %d\n" % (len(font.glyphs),))
	for glyph in font.glyphs:
		scalable_width = int(1000.0 * glyph.advance
				/ properties["PIXEL_SIZE"])
		stream.write("STARTCHAR %s\n" % (glyph.name,))
		stream.write("ENCODING %d\n" % (glyph.codepoint,))
		stream.write("SWIDTH %d 0\n" % (scalable_width,))
		stream.write("DWIDTH %d 0\n" % (glyph.advance,))
		stream.write("BBX %d %d %d %d\n"
				% (glyph.bbW, glyph.bbH, glyph.bbX, glyph.bbY))
		stream.write("BITMAP\n")
		for row in glyph.get_data():
			stream.write("%s\n" % (row,))
		stream.write("ENDCHAR\n")

	stream.write("ENDFONT\n")

# util
class Tally(object):
	"""
	Keeps count of things and prints a pretty list.
	"""

	def __init__(self, caption="", itemname="item"):
		self.counter = {}
		self.caption = caption
		self.itemname = itemname

	def record(self, item):
		"""
		Record that we've seen one more instance of the given item.

		item should be a hashable.
		"""
		if item in self.counter:
			self.counter[item] += 1
		else:
			self.counter[item] = 1

	def show(self, formatter=None):
		"""
		Print the result of the tally.

		formatter should be a callable that takes an item and returns a pretty
		string. If not supplied, repr() is used.
		"""
		if formatter is None:
			formatter = repr

		data = [(value, key) for key,value in list(self.counter.items())]
		data.sort()

		if len(data) == 0:
			return
		
		if self.caption:
			print(self.caption)
		print("count %s" % self.itemname)
		for count, item in data:
			print("%5d %s" % (count, formatter(item)))

# effects
def embolden(font, maintain_spacing=True):
	res = font.copy()

	for cp in res.codepoints():
		g = res[cp]
		g.merge_glyph(g, 1,0)
		if maintain_spacing:
			g.advance += 1

	return res


def merge(base, custom):
	res = custom.copy()

	for cp in base.codepoints():
		if cp not in res:
			old_glyph = base[cp]
			res.new_glyph_from_data(old_glyph.name, old_glyph.get_data(),
					old_glyph.bbX, old_glyph.bbY, old_glyph.bbW, old_glyph.bbH,
					old_glyph.advance, old_glyph.codepoint)

	return res

# glyph_combining

# There are many ways in which one character might be said to be 'made up of'
# other characters. We're only interested in the ones that involve graphically
# drawing one character overlaid on or beside another.
USEFUL_COMPOSITION_TYPES = [
		'<compat>',
		'<noBreak>',
	]

# Combining class names. Summarised from
# http://unicode.org/Public/UNIDATA/UCD.html#Canonical_Combining_Class_Values
CC_SPACING			= 0		# Spacing, split, enclosing, reordrant, etc.
CC_OVERLAY			= 1		# Overlays and interior
CC_NUKTAS			= 7		# Nuktas
CC_VOICING_MARKS	= 8		# Hiragana/Katakana voicing marks
CC_VIRAMAS			= 9		# Viramas
CC_BL_ATTACHED		= 200	# Bottom-left attached
CC_B_ATTACHED		= 202	# Bottom attached
CC_BR_ATTACHED		= 204	# Bottom-right attached
CC_L_ATTACHED		= 208	# Left attached
CC_R_ATTACHED		= 210	# Right attached
CC_AL_ATTACHED		= 212	# Above-left attached
CC_A_ATTACHED		= 214	# Above attached
CC_AR_ATTACHED		= 216	# Above-right attached
CC_BL				= 218	# Below-left
CC_B				= 220	# Below
CC_BR				= 222	# Below-right
CC_L				= 224	# Left
CC_R				= 226	# Right
CC_AL				= 228	# Above-left
CC_A				= 230	# Above
CC_AR				= 232	# Above-right
CC_B_DOUBLE			= 233	# Double below
CC_A_DOUBLE			= 234	# Double above
CC_IOTA_SUBSCRIPT	= 240	# Below (iota subscript)

# Combining glyphs can be drawn in different places on the base glyph; the
# combining class determines exactly where.
SUPPORTED_COMBINING_CLASSES = [
		CC_SPACING,
		CC_A,
		CC_B,
		CC_B_ATTACHED,
	]

# Combining classes that mean "draw the combining character above the base
# character". These cause characters with the "Soft_Dotted" property to be
# treated specially.
ABOVE_COMBINING_CLASSES = [CC_A, CC_A_ATTACHED]

# Characters with the "Soft_Dotted" property are treated specially a combining
# character is drawn above them; the dot is not drawn. Since Python's
# unicodedata module won't tell us what properties a character has, we'll have
# to hard-code the list ourselves.
SOFT_DOTTED_CHARACTERS = {
		"i": "\N{LATIN SMALL LETTER DOTLESS I}",
		"j": "\N{LATIN SMALL LETTER DOTLESS J}",
	}


def build_unicode_decompositions():
	"""
	Returns a dictionary mapping unicode chars to their component glyphs.
	"""
	res = {}

	for codepoint in range(0, sys.maxunicode + 1):
		curr_char = chr(codepoint)
		hex_components = unicodedata.decomposition(curr_char).split()

		if hex_components == []:
			# No decomposition at all, who cares?
			continue

		# If this combining-char sequence has a special type...
		if hex_components[0].startswith('<'):
			composition_type = hex_components[0]
			# ...is it a type we like?
			if composition_type in USEFUL_COMPOSITION_TYPES:
				# Strip the type, use the rest of the sequence
				hex_components = hex_components[1:]
			else:
				# This sequence is no good to us, let's move on.
				continue

		# Convert ['aaaa', 'bbbb'] to [u'\uaaaa', u'\ubbbb'].
		components = [chr(int(cp,16)) for cp in hex_components]

		# Handle soft-dotted characters.
		if components[0] in SOFT_DOTTED_CHARACTERS and len(components) > 1:
			above_components = [c for c in components[1:]
					if unicodedata.combining(c) in ABOVE_COMBINING_CLASSES]
			# If there are any above components...
			if len(above_components) > 0:
				# ...replace the base character with its undotted equivalent.
				components[0] = SOFT_DOTTED_CHARACTERS[components[0]]

		# Look up the combining classes, too
		res[curr_char] = [(char, unicodedata.combining(char))
				for char in components]

	return res


class FontFiller(object):
	"""
	Utility class for filling out a font based on combining characters.
	"""

	def __init__(self, font, decompositions):
		self.font = font
		self.decompositions = decompositions
		self.missing_chars = Tally("Missing combinable characters", "char")
		self.unknown_classes = Tally("Unknown combining classes")

	def add_glyph_to_font(self, char):
		"""
		Add the glyph representing char to the given font, if it can be built.
		"""

		if ord(char) in self.font:
			# It's already there!
			return True

		if char not in self.decompositions:
			# We don't know how to build it.
			return False

		components = self.decompositions[char]
		for component_char, combining_class in components:
			if combining_class not in SUPPORTED_COMBINING_CLASSES:
				# We don't know how to combine this with other characters.
				self.unknown_classes.record(combining_class)
				return False

			if not self.add_glyph_to_font(component_char):
				# We don't know how to build one of the required components.
				self.missing_chars.record(component_char)
				return False

		# Now we have all the components, let's put them together!
		glyph = self.font.new_glyph_from_data("char%d" % ord(char),
				codepoint=ord(char))

		# Draw on the base char.
		base_char = components[0][0]
		base_combining_class = components[0][1]
		assert base_combining_class == CC_SPACING, \
				"base char should be a spacing char"
		base_glyph = self.font[ord(base_char)]
		glyph.merge_glyph(base_glyph, 0,0)
		glyph.advance = base_glyph.advance

		for component_char, combining_class in components[1:]:
			other_glyph = self.font[ord(component_char)]

			if combining_class == CC_SPACING:
				# Draw other_glyph beside the current glyph
				glyph.merge_glyph(other_glyph, glyph.advance,0)
				glyph.advance += other_glyph.advance

			elif combining_class == CC_A:
				# Draw other_glyph centred above the current glyph
				y_offset = 0
				x_offset = 0

				if "CAP_HEIGHT" in self.font and glyph.bbH > 0:
					# We assume combining glyphs are drawn above the
					# CAP_HEIGHT.
					y_offset = glyph.get_ascent() - self.font["CAP_HEIGHT"]

				if glyph.bbW > 0:
					x_offset = int(
							float(glyph.advance)/2
							- float(other_glyph.advance)/2
						)

				glyph.merge_glyph(other_glyph, x_offset,y_offset)
			elif combining_class in (CC_B, CC_B_ATTACHED):
				# Draw other_glyph centred below the current glyph
				y_offset = -glyph.get_descent()
				x_offset = 0

				if glyph.bbW > 0:
					x_offset = int(
							float(glyph.advance)/2
							- float(other_glyph.advance)/2
						)

				glyph.merge_glyph(other_glyph, x_offset,y_offset)
			else:
				raise RuntimeError("Unsupported combining class %d" %
						(combining_class,))

		return True

	def add_decomposable_glyphs_to_font(self):
		"""
		Adds all the glyphs that can be built to the given font.
		"""
		for char in self.decompositions:
			self.add_glyph_to_font(char)

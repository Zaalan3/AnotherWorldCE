# ----------------------------
# Makefile Options
# ----------------------------

NAME = ANOTHERW
ICON = icon.png
DESCRIPTION = "Another World Interpreter."
COMPRESSED = NO
ARCHIVED = YES
LTO = YES

CFLAGS = -Wall -Wextra -Oz
CXXFLAGS = -Wall -Wextra -Oz

# ----------------------------

include $(shell cedev-config --makefile)

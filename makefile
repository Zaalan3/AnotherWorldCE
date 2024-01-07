# ----------------------------
# Makefile Options
# ----------------------------

NAME = ANOTHERW
ICON = icon.png
DESCRIPTION = "Another World Interpreter."
COMPRESSED = YES
ARCHIVED = YES
LTO = YES

BSSHEAP_LOW = D052C6
BSSHEAP_HIGH = D177B6

CFLAGS = -Wall -Wextra -Oz
CXXFLAGS = -Wall -Wextra -Oz

# ----------------------------

include $(shell cedev-config --makefile)

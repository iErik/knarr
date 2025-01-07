package print

import "core:encoding/ansi"

SEP   :: ";"
ESC   :: ansi.ESC
CSI   :: ansi.CSI
SGR   :: ansi.SGR
RESET :: ansi.RESET


BOLD      :: ansi.BOLD
DIM       :: ansi.FAINT
ITALIC    :: ansi.ITALIC
UNDERLINE :: ansi.UNDERLINE
BLINKING  :: ansi.BLINK_SLOW
REVERSED  :: ansi.INVERT
HIDDEN    :: ansi.HIDE
STRIKE    :: ansi.STRIKE


BLACK   :: ansi.FG_BLACK
RED     :: ansi.FG_RED
GREEN   :: ansi.FG_GREEN
YELLOW  :: ansi.FG_YELLOW
BLUE    :: ansi.FG_BLUE
MAGENTA :: ansi.FG_MAGENTA
CYAN    :: ansi.FG_CYAN
WHITE   :: ansi.FG_WHITE
DEFAULT :: ansi.FG_DEFAULT

SET_FG  :: ansi.FG_COLOR
SET_BG  :: ansi.BG_COLOR

BG_BLACK   :: ansi.BG_BLACK
BG_RED     :: ansi.BG_RED
BG_GREEN   :: ansi.BG_GREEN
BG_YELLOW  :: ansi.BG_YELLOW
BG_BLUE    :: ansi.BG_BLUE
BG_MAGENTA :: ansi.BG_MAGENTA
BG_CYAN    :: ansi.BG_CYAN
BG_WHITE   :: ansi.BG_WHITE
BG_DEFAULT :: ansi.BG_DEFAULT


B_BLACK   :: ansi.FG_BRIGHT_BLACK
B_RED     :: ansi.FG_BRIGHT_RED
B_GREEN   :: ansi.FG_BRIGHT_GREEN
B_YELLOW  :: ansi.FG_BRIGHT_YELLOW
B_BLUE    :: ansi.FG_BRIGHT_BLUE
B_MAGENTA :: ansi.FG_BRIGHT_MAGENTA
B_CYAN    :: ansi.FG_BRIGHT_CYAN
B_WHITE   :: ansi.FG_BRIGHT_WHITE

BG_B_BLACK   :: ansi.BG_BRIGHT_BLACK
BG_B_RED     :: ansi.BG_BRIGHT_RED
BG_B_GREEN   :: ansi.BG_BRIGHT_GREEN
BG_B_YELLOW  :: ansi.BG_BRIGHT_YELLOW
BG_B_BLUE    :: ansi.BG_BRIGHT_BLUE
BG_B_MAGENTA :: ansi.BG_BRIGHT_MAGENTA
BG_B_CYAN    :: ansi.BG_BRIGHT_CYAN
BG_B_WHITE   :: ansi.BG_BRIGHT_WHITE


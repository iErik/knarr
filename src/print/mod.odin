package print

import "core:fmt"
import "core:encoding/ansi"


GraphicsMode :: enum {
  Default,
  Bright,
  Bold,
  Dim,
  Italic,
  Underline,
  Blinking,
  Reversed,
  Hidden,
  Strike
}

GraphicsMode_Set :: bit_set[GraphicsMode]


strappend :: proc (str1, str2: string) -> string {
  return fmt.aprintf("%s%s", str1, str2)
}


err :: proc (msg: string, args: ..any) {
  fmt.eprintfln(red(msg), ..args)
}

warn :: proc (msg: string, args: ..any) {
  fmt.printfln(yellow(msg), ..args)
}

info :: proc (msg: string, args: ..any) {
  fmt.printfln(blue(msg), ..args)
}

success :: proc (msg: string, args: ..any) {
  fmt.printfln(green(msg), ..args)
}

msg :: proc (msg: string, args: ..any) {
  fmt.printfln(default(msg), ..args)
}



// Colors
// ------

color :: proc (color, input: string) -> string {
  return fmt.aprintf("%s%s%s", color, input, CSI+RESET+SGR)
}

@(private="file")
modes_select :: proc (
  cnormal, cbright: string,
  modes: GraphicsMode_Set
) -> string {
  C := CSI

  if .Bright in modes do C = strappend(C, cbright)
  else do C = strappend(C, cnormal)

  if .Bold in modes do      C = strappend(C, SEP+BOLD)
  if .Dim in modes do       C = strappend(C, SEP+DIM)
  if .Italic in modes do    C = strappend(C, SEP+ITALIC)
  if .Underline in modes do C = strappend(C, SEP+UNDERLINE)
  if .Blinking in modes do  C = strappend(C, SEP+BLINKING)
  if .Reversed in modes do  C = strappend(C, SEP+REVERSED)
  if .Hidden in modes do    C = strappend(C, SEP+HIDDEN)
  if .Strike in modes do    C = strappend(C, SEP+STRIKE)

  C = strappend(C, SGR)

  return C
}

@(private="file")
color_compose :: proc (
  input, cnormal, cbright: string,
  modes: GraphicsMode_Set,
) -> string {
  return color(modes_select(cnormal, cbright, modes), input)
}

black :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BLACK, B_BLACK, mode)
}

red :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, RED, B_RED, mode)
}

green :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, GREEN, B_GREEN, mode)
}

yellow :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, YELLOW, B_YELLOW, mode)
}

blue :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BLUE, B_BLUE, mode)
}

magenta :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, MAGENTA, B_MAGENTA, mode)
}

cyan :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, CYAN, B_CYAN, mode)
}

white :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, WHITE, B_WHITE, mode)
}

default :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, DEFAULT, DEFAULT, mode)
}


// Background colors
// -----------------

on_black :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_BLACK, BG_B_BLACK, mode)
}

on_red :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_RED, BG_B_RED, mode)
}

on_green :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_GREEN, BG_B_GREEN, mode)
}

on_yellow :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_YELLOW, BG_B_YELLOW, mode)
}

on_blue :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_BLUE, BG_B_BLUE, mode)
}

on_magenta :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_MAGENTA, BG_B_MAGENTA, mode)
}

on_cyan :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_CYAN, BG_B_CYAN, mode)
}

on_white :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_WHITE, BG_B_WHITE, mode)
}

on_default :: proc (
  input: string,
  mode: GraphicsMode_Set = {}
) -> string {
  return color_compose(input, BG_DEFAULT, BG_DEFAULT, mode)
}



package knarr

import "core:fmt"
import "core:encoding/ini"
import "core:os"
import fl "core:flags"

read_from_filename :: os.read_entire_file_from_filename
read_from_handle :: os.read_entire_file_from_handle

map_from_str :: ini.load_map_from_string


Task :: enum {
  BUILD,
  WATCH,
  RUN
}

RUN_CMD   :: "run"
BUILD_CMD :: "build"
WATCH_CMD :: "watch"

CmdFlags :: struct {
  config: os.Handle `args:"file=r"`
}

OptionsSchema :: struct {
  pkgName: string,
  pkgRoot: string,
  outDir:  string,
  tempDir: string,

  collections: map[string]string,
  watchDirs: []string
}


parse_from_str :: proc (path: string) -> (ok: bool) {
  buffer := read_from_filename(path) or_return
  contents := transmute(string) buffer

  raw_map, err := map_from_str(contents, context.allocator)

  fmt.printfln("Map: %v", raw_map)
  return
}

parse_from_fd :: proc (fd: os.Handle) -> (ok: bool) {
  buffer := read_from_handle(fd) or_return
  contents := transmute(string) buffer

  raw_map, err := map_from_str(contents, context.allocator)
  fmt.printfln("Map: %v", raw_map)

  return
}

parse_config :: proc (config: ini.Map) {

}

get_args :: proc () -> (task: Task, flags: CmdFlags) {
  if len(os.args) <= 1 {
    fmt.printfln("You must provide me a task.")
    return
  }

  switch os.args[1] {
    case RUN_CMD:   task = .RUN
    case BUILD_CMD: task = .BUILD
    case WATCH_CMD: task = .WATCH
    case:
      fmt.printfln("Invalid task: %v", os.args[1])
      return
  }

  args := os.args[1:]

  fl.parse_or_exit(&flags, args, .Unix)

  return
}

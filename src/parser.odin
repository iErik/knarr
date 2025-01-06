package knarr

import "base:runtime"
import "core:strings"
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
  RUN,
  INSTALL
}

RUN_CMD   :: "run"
BUILD_CMD :: "build"
WATCH_CMD :: "watch"
INSTALL   :: "install"

CmdFlags :: struct {
  config: os.Handle `args:"file=r"`
}

TaskOptions :: struct {
  pkgName: string,
  pkgRoot: string,
  outDir:  string,
  tempDir: string,

  collections: map[string]string,
  watchDirs: []string
}


DEFAULT_CONFIG_PATH :: "./package.ini"

DEFAULT_OPTS :: TaskOptions {
  pkgName = "unnamed",
  pkgRoot = "./src",
  tempDir = ".tmp",
  outDir  = "build"
}

REQUIRED_KEYS :: [?]string {
  "package.name",
  "package.src"
}


map_from_buffer :: proc (buffer: []u8) -> (
  raw_map: ini.Map,
  ok: bool = true
) {
  contents := transmute(string) buffer

  err : runtime.Allocator_Error
  raw_map, err = map_from_str(contents, context.allocator)

  if err != .None {
    fmt.printfln(
      "Allocator error while parsing" +
      "configuration file: %s", err)

    ok = false
    return
  }

  return
}

parse_map :: proc (config: ini.Map) -> (
  opts: TaskOptions,
  ok: bool = true
) {
  for key in REQUIRED_KEYS {
    if has_key(key, config) do continue

    fmt.eprintfln("Configuration key \"%v\" is missing!",
      key)

    ok = false
    return
  }

  fb := DEFAULT_OPTS
  pkg := config["package"]
  collections, has_collections := config["collections"]

  opts = TaskOptions {
    pkgName = pkg["name"]     or_else fb.pkgName,
    pkgRoot = pkg["src"]      or_else fb.pkgRoot,
    outDir  = pkg["out-dir"]  or_else fb.outDir,
    tempDir = pkg["temp-dir"] or_else fb.tempDir,
    collections = collections
  }

  opts.collections["root"] = opts.pkgName

  return
}

map_from_path :: proc (path: string) -> (
  raw_map: ini.Map,
  ok: bool = true
) {
  if !os.exists(path) do return {}, false

  buffer := read_from_filename(path) or_return
  raw_map = map_from_buffer(buffer) or_return

  return
}

map_from_fd :: proc (fd: os.Handle) -> (
  raw_map: ini.Map,
  ok: bool = true
) {
  buffer := read_from_handle(fd) or_return
  raw_map = map_from_buffer(buffer) or_return

  return
}

make_map :: proc {
  map_from_str,
  map_from_fd,
}

get_args :: proc () -> (
  task: Task,
  options: TaskOptions,
  ok: bool = true
) {
  if len(os.args) <= 1 {
    fmt.printfln("You must provide me a task.")
    ok = false
    return
  }

  switch os.args[1] {
    case RUN_CMD:   task = .RUN
    case BUILD_CMD: task = .BUILD
    case WATCH_CMD: task = .WATCH
    case:
      fmt.printfln("Invalid task: %v", os.args[1])
      ok = false
      return
  }

  flags : CmdFlags
  fl.parse_or_exit(&flags, os.args[1:], .Unix)

  if flags.config > 0 {
    raw_map := map_from_fd(flags.config) or_return
    options, ok = parse_map(raw_map)
    return
  }

  if os.exists(DEFAULT_CONFIG_PATH) {
    raw_map := map_from_path(DEFAULT_CONFIG_PATH) or_return
    options, ok = parse_map(raw_map)
    return
  }

  options = DEFAULT_OPTS
  return
}


has_key :: proc (
  key: string,
  src: ini.Map
) -> bool {
  keys := strings.split(key, ".")
  parent, child := keys[0], keys[1]

  if parent == "" do return false
  if child == "" do return parent in src

  return child in src[parent]
}


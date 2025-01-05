package knarr

import "core:sync/chan"

import "core:fmt"
import "core:strings"
import sys "core:sys/linux"
import dyn "core:dynlib"

import "core:slice"
import "core:sys/posix"
import "core:encoding/json"
import "core:c/libc"

import "core:encoding/ansi"
import glfw "vendor:glfw"

Win :: glfw.WindowHandle
DLLExt :: dyn.LIBRARY_FILE_EXTENSION
Err :: sys.Errno

FakeSet :: map[string]struct{}

add_keys :: proc (keys: []string, dest: ^FakeSet) {
  for key in keys do dest[key] = {}
}

HMROptions :: struct {
  pkgPath:   string,
  pkgName:   string,
  outDir:    string,
  extradirs: []string,
  pkgSuffix: string,
  pkgPrefix: string,

  buildArgs: string,
  collections: []string,

  __version: i32
}

PackageApi :: struct {
	lib: dyn.Library,
  ctx: rawptr,

	init_window: proc() -> (win: Win, ok: bool),
  init_context: proc() -> (ctx: rawptr, ok: bool),
  setup: proc (ctx: rawptr),
  window: proc(ctx: rawptr) -> Win,

  fresh_start: proc() -> (ctx: rawptr, ok: bool),

  should_loop: proc(ctx: rawptr) -> bool,
	update: proc(ctx: rawptr),
  render: proc(ctx: rawptr),
  reload: proc(ctx: rawptr) -> (ok: bool),

  destroy: proc(ctx: rawptr),
	shutdown_window: proc(win: Win),
}

BuildOpts :: struct {
  pkgPath:   string,
  pkgName:   string,
  outDir:    string,
  pkgSuffix: string,
  pkgPrefix: string,
  extraArgs: string,
  collections: []string
}

BuildResult :: struct {
  output: json.Value,
  parseErr: json.Error,
  status: i32
}

odin_build :: proc (using opts: HMROptions) -> (
  result: BuildResult,
  err: Err
) {
  finalPkgName := fmt.tprintf("%v%v%v_%d",
    pkgPrefix,
    pkgName,
    pkgSuffix,
    __version)

  cmd := strjoin({
    strcat({"odin build ", pkgPath}),
    strcat({"-out:", outDir, finalPkgName}),
    "-build-mode:dynamic",
    "-debug",
    "-json-errors",
    buildArgs
  }, " ")

  print_info("Building target...")
  print_info("Pkg name: %v EXT: %v", finalPkgName, DLLExt)
  ret := run_cmd(cmd) or_return

  data, error := json.parse_string(ret.output)

  result.status = ret.status
  result.output = data
  result.parseErr = error
  print_msg("Package built.")
  print_info("Build output: %v\n", data)

  return
}

odin_run :: proc (using opts: HMROptions) -> (
  result: BuildResult,
  err: Err
) {
  finalPkgName := fmt.tprintf("%v%v%v_%d",
    pkgPrefix,
    pkgName,
    pkgSuffix,
    __version)

  cmd := strjoin({
    strcat({"odin build ", pkgPath}),
    strcat({"-out:", outDir, finalPkgName}),
    "-build-mode:dynamic",
    "-debug",
    "-json-errors",
    buildArgs
  }, " ")

  print_info("Building target...")
  ret := run_cmd(cmd) or_return

  data, error := json.parse_string(ret.output)

  result.status = ret.status
  result.output = data
  result.parseErr = error
  print_msg("Package built.")
  print_info("Build output: %v\n", data)

  return
}

kickoff_target :: proc (opts: HMROptions) -> Err {
  stat :sys.Stat
  err := sys.lstat(".tmp/", &stat)

  if err == .ENOENT {
    dirErr := sys.mkdir(".tmp", {
      .IFDIR,
      .IRUSR,
      .IWUSR,
      .IXUSR
    })

    if dirErr != .NONE {
      print_err(
        "Could not create temporary directory: %s", dirErr)
      return dirErr
    }

  } else if err != .NONE {
    print_err("Could not load target project: %s", err)
    return err
  }

  odin_build(opts) or_return

  return .NONE
}

load_target :: proc (opts: HMROptions) -> (
  api: ^PackageApi,
  err: Err
) {
  api = new(PackageApi)

  dll_name := fmt.tprintf("%v%v%v%v_%d.%v",
    opts.outDir,
    opts.pkgPrefix,
    opts.pkgName,
    opts.pkgSuffix,
    opts.__version,
    DLLExt)

  print_info("Loading DLL: %v ...\n", dll_name)

  _, ok := dyn.initialize_symbols(api, dll_name, "", "lib")

  if !ok {
    print_err("Could not load library")
    err = .ELIBACC
  }

  print_msg("DLL loaded sucessfully")

  return
}

reload_target :: proc (
  ctx: rawptr,
  opts: HMROptions
) -> (api: ^PackageApi, err: Err) {

  dll_name := fmt.tprintf("%v%v%v%v_%d.%v",
    opts.outDir,
    opts.pkgPrefix,
    opts.pkgName,
    opts.pkgSuffix,
    opts.__version,
    DLLExt)

  api = new(PackageApi)
  print_info("Reloading DLL: %v ...\n", dll_name)

  _, ok := dyn.initialize_symbols(api, dll_name, "", "lib")

  if !ok {
    err = .ELIBACC

    print_err("Failed to initialize library symbols: %v",
      dyn.last_error())

    return
  }

  api.ctx = ctx
  reload_ok := api.reload(ctx)

  if !reload_ok {
    print_err("Could not reload library!")
    err = .ELIBACC
    return
  }

  print_msg("DLL reloaded sucessfully")

  return
}

unload_target :: proc (api: ^PackageApi) -> Err {
  ok := dyn.unload_library(api.lib)

  if !ok {
    print_err("Failed to unload library: %v",
      dyn.last_error())
    return .ECANCELED
  }

  print_msg("Library unloaded sucessfully")

  return .NONE
}

watch :: proc (options: HMROptions) {
  options := options
  options.__version = 0

  kErr := kickoff_target(options)
  api, api_err := load_target(options)

  if api_err != .NONE {
    print_err(
      "Received API Error %s. Process exiting",
      api_err)

    return
  }

  print_info("Initializing context...")
  ctx, err := api.fresh_start()
  api.ctx = ctx
  options.__version += 1
  print_info("Context Initialized")

  listener :EventHandler = proc (
    ev: InotifyEv,
    ch: chan.Chan(bool)
  ) {
    print_info("I've received an event: %v", ev)

    ok := chan.try_send(ch, true)
    print_info("Try send status: %v", ok)
  }

  print_info("Setting up watcher")
  dirSet := FakeSet{ options.pkgPath = {} }
  add_keys(options.extradirs, &dirSet)
  paths, _ := map_keys(dirSet)

  thr, chn, wErr := async_watch(paths, listener)

  if wErr != .NONE {
    print_err("Async watch error!")
  }

  for api.should_loop(api.ctx) {
    should_reload, ok := chan.try_recv(chn)

    if should_reload {
      print_info("Application should reload now!")
      odin_build(options)
      new_api, errno := reload_target(api.ctx, options)

      if errno != .NONE {
        print_err("Could not reload target: %s", err)
      }

      options.__version += 1
    }

    api.update(api.ctx)
    api.render(api.ctx)
  }
}

main :: proc () {
  /*
  options := HMROptions {
    pkgPath   = "./src",
    pkgName   = "geenie",
    outDir    = ".tmp/",
    pkgSuffix = "_hmr",
    pkgPrefix = "tmp_",

    extradirs = []string{"./shaders", "./assets"},

    buildArgs = strjoin({
      "-collection:gini=./src/gini",
      "-collection:package=./src"
    }, " ")
  }

  watch(options)
  */

  get_args()
}

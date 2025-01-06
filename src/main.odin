package knarr

import "core:fmt"
import "core:encoding/json"
import "core:sync/chan"
import sys "core:sys/linux"

import glfw "vendor:glfw"


Win :: glfw.WindowHandle
Err :: sys.Errno

HMROptions :: struct {
  pkgPath:   string,
  pkgName:   string,
  outDir:    string,
  extradirs: []string,
  pkgSuffix: string, //#
  pkgPrefix: string, // #

  buildArgs: string, // #
  collections: []string,

  __version: i32 // #
}


watch :: proc (options: TaskOptions) {
  odin_opts := OdinOptions {
    pkgRoot = options.pkgRoot,
    pkgName = options.pkgName,
    outDir  = options.tempDir,
    collections = options.collections,

    pkgPrefix = "tmp_",
    pkgSuffix = "_hmr",
    version   = 0,

    extraArgs = strjoin({
      "-build-mode:dynamic",
      "-debug",
      "-json-errors",
    }, " ")
  }

  result, cmd_err := odin_do(.BUILD, odin_opts)
  api, api_err := load_target(odin_opts)
  output, js_err := json.parse_string(result.output)

  if api_err != .NONE {
    print_err(
      "Received API Error %s. Process exiting",
      api_err)

    return
  }

  ctx, err := api.fresh_start()
  api.ctx = ctx
  odin_opts.version += 1

  listener :EventHandler = proc (
    ev: InotifyEv,
    ch: chan.Chan(bool)
  ) { ok := chan.try_send(ch, true) }

  dirSet := FakeSet{ options.pkgRoot = {} }
  add_keys(options.watchDirs, &dirSet)
  paths, _ := map_keys(dirSet)

  thr, chn, wErr := async_watch(paths, listener)

  if wErr != .NONE {
    print_err("Async watch error!")
  }

  for api.should_loop(api.ctx) {
    should_reload, ok := chan.try_recv(chn)

    if should_reload {
      print_info("Application should reload now!")
      odin_do(.BUILD, odin_opts)
      new_api, errno := reload_target(api.ctx, odin_opts)

      if errno != .NONE {
        print_err("Could not reload target: %s", err)
      }

      odin_opts.version += 1
    }

    api.update(api.ctx)
    api.render(api.ctx)
  }
}

run :: proc (options: TaskOptions) {
  odin_opts := OdinOptions {
    pkgRoot = options.pkgRoot,
    pkgName = options.pkgName,
    outDir  = options.tempDir,
    collections = options.collections,

    pkgPrefix = "tmp_",
    pkgSuffix = "",
    version   = 0,

    extraArgs = "-debug"
  }

  fmt.printfln("Running...")
  odin_do(.RUN, odin_opts)

  return
}

build :: proc (options: TaskOptions) {
  odin_opts := OdinOptions {
    pkgRoot = options.pkgRoot,
    pkgName = options.pkgName,
    outDir  = options.outDir,
    collections = options.collections,

    pkgPrefix = "tmp_",
    pkgSuffix = "",
    version   = 0,

    extraArgs = ""
  }

  fmt.printfln("Building...")
  odin_do(.BUILD, odin_opts)

  return
}

main :: proc () {
  task, options, ok := get_args()

  fmt.printfln("Task: %s", task)
  fmt.printfln("Options: %v", options)

  if !ok do return

  switch task {
    case .BUILD: build(options)
    case .WATCH: watch(options)
    case .RUN:   run(options)
    case .INSTALL:
  }

  return
}

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


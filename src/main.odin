package knarr

import "core:fmt"
import "core:encoding/json"
import "core:sync/chan"
import sys "core:sys/linux"

import "root:print"

Err :: sys.Errno

// TODO : INTRODUCE THE POSSIBILITY OF DECLARING
// A "LIBRARY" DIRECTORY (E.G. "~/OdinPkgs") WHERE
// SHARED LIBS ARE PLACED, CALL IT LIBS!

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
  output, js_err  := json.parse_string(result.output)
  api, dll_err    := load_target(odin_opts)
  ctx, ok_start   := api.fresh_start()
  api.ctx = ctx
  odin_opts.version += 1

  listener :EventHandler = proc (
    ev: InotifyEv,
    ch: chan.Chan(bool)
  ) { ok := chan.try_send(ch, true) }

  dirs := FakeSet{ options.pkgRoot = {} }
  set_push(options.pkgRoot, &dirs)
  set_push(options.watchDirs, &dirs)

  thr, chn, watch_err := async_watch(
    set_items(dirs), listener)

  switch {
    case cmd_err != .NONE:
      print.err("Failed to compile package: %s", cmd_err)
      return
    case js_err  != .None:
      print.err("Failed to parse build output: %s", cmd_err)
      return
    case dll_err != .NONE:
      print.err("Failed to load package dynamically: %s",
        dll_err)
      return
    case !ok_start:
      print.err("Failed to start application!")
      return
    case watch_err != .NONE:
      print.err("Failed to setup file watcher: %s",
        watch_err)
      return
  }

  for api.should_loop(api.ctx) {
    should_reload, ok := chan.try_recv(chn)

    if should_reload {
      print.info("Application should reload now!")

      odin_do(.BUILD, odin_opts)
      new_api, errno := reload_target(api.ctx, odin_opts)

      if errno != .NONE {
        print.err("Could not reload target: %s", errno)
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

  print.info("Running with options:\n%v\n", options)
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

  if !ok do return

  switch task {
    case .BUILD: build(options)
    case .WATCH: watch(options)
    case .RUN:   run(options)
    case .INSTALL:
  }

  return
}


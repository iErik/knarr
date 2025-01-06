package knarr

import "core:fmt"
import dyn "core:dynlib"
import sys "core:sys/linux"

DLLExt :: dyn.LIBRARY_FILE_EXTENSION

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

load_target :: proc (opts: OdinOptions) -> (
  api: ^PackageApi,
  err: Err
) {
  api = new(PackageApi)

  dll_name := fmt.tprintf("%v%v%v%v_%d.%v",
    opts.outDir,
    opts.pkgPrefix,
    opts.pkgName,
    opts.pkgSuffix,
    opts.version,
    DLLExt)

  _, ok := dyn.initialize_symbols(api, dll_name, "", "lib")

  if !ok {
    print_err("Could not load library")
    err = .ELIBACC
  }

  return
}

reload_target :: proc (
  ctx: rawptr,
  opts: OdinOptions
) -> (api: ^PackageApi, err: Err) {

  dll_name := fmt.tprintf("%v%v%v%v_%d.%v",
    opts.outDir,
    opts.pkgPrefix,
    opts.pkgName,
    opts.pkgSuffix,
    opts.version,
    DLLExt)

  api = new(PackageApi)

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

  return
}

unload_target :: proc (api: ^PackageApi) -> Err {
  ok := dyn.unload_library(api.lib)

  if !ok {
    print_err("Failed to unload library: %v",
      dyn.last_error())
    return .ECANCELED
  }

  return .NONE
}


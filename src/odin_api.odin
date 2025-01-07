package knarr

import "core:fmt"
import "core:encoding/json"
import "core:path/filepath"


BuildResult :: struct {
  output: json.Value,
  parseErr: json.Error,
  status: i32
}

OdinTask :: enum {
  BUILD,
  RUN
}

OdinOptions :: struct {
  pkgName: string,
  pkgRoot: string,
  outDir:  string,

  pkgPrefix: string,
  pkgSuffix: string,
  version:   i32,

  collections: map[string]string,
  extraArgs: string,
}

odin_do :: proc (
  task: OdinTask,
  using opts: OdinOptions
) -> (result: CmdResult, err: Err) {
  if !ensure_dir_exists(outDir) {
    err = .ENOENT
    return
  }

  finalPkgName := fmt.tprintf("%v%v%v_%d",
    pkgPrefix,
    pkgName,
    pkgSuffix,
    version)

  taskCmd :string
  _collections :string
  out := filepath.join({outDir, finalPkgName})

  switch task {
    case .BUILD: taskCmd = "build "
    case .RUN: taskCmd = "run "
  }

  for k, v in collections {
    _collections = fmt.aprintf("%s %s ",
      _collections,
      fmt.aprintf("collection:%s=%s", k, v))

    fmt.printfln("Col: %v=%v",k, v)
    fmt.printfln("_cols: %v", _collections)
  }

  cmd := strjoin({
    strcat({"odin ", taskCmd, pkgRoot}),
    strcat({"-out:", out}),
    _collections,
    extraArgs
  }, " ")

  ret := run_cmd(cmd) or_return
  return
}


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
  out := filepath.join({outDir, finalPkgName})

  switch task {
    case .BUILD: taskCmd = "build "
    case .RUN: taskCmd = "run "
  }

  for k, v in collections {
    fmt.printfln("Col: %v=%v",k, v)
  }

  cmd := strjoin({
    strcat({"odin ", taskCmd, pkgRoot}),
    strcat({"-out:", out}),
    extraArgs
  }, " ")

  ret := run_cmd(cmd) or_return
  fmt.printfln("OdinDo: %v", ret)
  fmt.printfln("TaskCMD: %v", taskCmd)
  fmt.printfln("cmd: %v", cmd)

  return
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

  ret := run_cmd(cmd) or_return

  data, error := json.parse_string(ret.output)

  result.status = ret.status
  result.output = data
  result.parseErr = error

  print_info("Build output: %v\n", data)

  return
}

odin_watch :: proc () {

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
    strcat({"odin run", pkgPath}),
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
  print_info("Build output: %v\n", data)

  return
}


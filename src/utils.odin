package knarr

import "core:encoding/ansi"
import "core:fmt"
import "core:strings"

import "core:slice"
import "core:sys/posix"
import sys "core:sys/linux"

strcat   :: strings.concatenate
strjoin  :: strings.join
strcclone :: strings.clone_to_cstring
bytetostr :: strings.clone_from_bytes
trimnull :: strings.trim_null
ptrtostr :: strings.string_from_ptr
slicecat :: slice.concatenate
map_keys :: slice.map_keys

PrintArg :: struct {
  format: string,
  value: any
}

print_err :: proc (msg: string, args: ..any) {
  msg := strcat({
    ansi.CSI + ansi.BOLD + ";" + ansi.FG_RED + ansi.SGR,
    msg,
    ansi.CSI + ansi.RESET + ansi.SGR
  })

  fmt.eprintfln(msg, ..args)
}

print_warn :: proc (msg: string, args: ..any) {
  msg := strcat({
    ansi.CSI + ansi.BOLD + ";" + ansi.FG_YELLOW + ansi.SGR,
    msg,
    ansi.CSI + ansi.RESET + ansi.SGR
  })

  fmt.printfln(msg, ..args)
}

print_info :: proc (msg: string, args: ..any) {
  msg := strcat({
    ansi.CSI + ansi.BOLD + ";" + ansi.FG_BLUE + ansi.SGR,
    msg,
    ansi.CSI + ansi.RESET + ansi.SGR
  })

  fmt.printfln(msg, ..args)
}

print_msg :: proc (msg: string, args: ..any) {
  msg := strcat({
    ansi.CSI + ansi.BOLD + ";" + ansi.FG_GREEN + ansi.SGR,
    msg,
    ansi.CSI + ansi.RESET + ansi.SGR
  })

  fmt.printfln(msg, ..args)
}

fgets :: proc (src: ^posix.FILE, buffer: []u8) -> [^]u8 {
  return posix.fgets(
    raw_data(buffer[:]),
    i32(len(buffer)),
    src)
}

CmdResult :: struct {
  output: string,
  status: i32
}

run_cmd :: proc (cmd: string) -> (
  result: CmdResult,
  err: Err,
) {
  //red := strings.clone_to_cstring(strcat({cmd, " 2>&1"}))
  //pipe := posix.popen(red, "r")
  // TODO: Sort that out
  pipe := posix.popen(strcclone(cmd), "r")

  if pipe == nil {
    print_err("Couldn't spawn command %v", cmd)
    err = sys.Errno(posix.get_errno())
    //err = .ENOMEM
    return
  }

  temp: [1024]u8
  for fgets(pipe, temp[:]) != nil {
    result.output = strcat({
      result.output,
      strings.trim_null(strings.clone_from_bytes(temp[:]))
    })

    temp = {}
  }

  result.status = posix.pclose(pipe)
  return
}

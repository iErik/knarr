package knarr

import "core:fmt"
import "core:strings"

import "core:slice"
import "core:sys/posix"
import sys "core:sys/linux"

import "core:os"

import "root:print"



strcat   :: strings.concatenate
strjoin  :: strings.join
strcclone :: strings.clone_to_cstring
bytetostr :: strings.clone_from_bytes
trimnull :: strings.trim_null
ptrtostr :: strings.string_from_ptr
slicecat :: slice.concatenate
map_keys :: slice.map_keys



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

run_cmd :: proc (cmd: string, redirect: bool = false) -> (
  result: CmdResult,
  err: Err,
) {
  cmd := cmd
  if redirect do cmd = strcat({cmd, " 2>&1"})
  pipe := posix.popen(strcclone(cmd), "r")

  if pipe == nil {
    print.err("Couldn't spawn command %v", cmd)
    err = sys.Errno(posix.get_errno())
    return
  }

  temp: [1024]u8
  for fgets(pipe, temp[:]) != nil {
    result.output = strcat({
      result.output,
      strings.trim_null(bytetostr(temp[:]))
    })

    temp = {}
  }

  result.status = posix.pclose(pipe)
  return
}

ensure_dir_exists :: proc (dirname: string) -> (ok: bool) {
  if os.is_dir(dirname) do return true
  err := os.make_directory(dirname)

  if err != os.ERROR_NONE {
    print.err("Failed to create directory \"%v\": %s",
      dirname, err)

    return false
  }

  return true
}

// FakeSet
// -------

FakeSet :: map[string]struct{}

set_push_one :: proc (key: string, dest: ^FakeSet) {
  dest[key] = {}
}

set_push_many :: proc (keys: []string, dest: ^FakeSet) {
  for key in keys do dest[key] = {}
}

set_push :: proc {
  set_push_one,
  set_push_many,
}

set_items :: proc (set: FakeSet) -> []string {
  items, _ := map_keys(set)
  return items
}

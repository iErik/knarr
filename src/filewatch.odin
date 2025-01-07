package knarr

import "core:time"
import "base:runtime"
import "core:thread"
import "core:sync/chan"
import "core:mem"
import "core:fmt"
import "core:strings"

import "core:slice"

import "core:sys/posix"
import sys "core:sys/linux"

import "root:print"

MAX_NAME_LEN :: 256
EVENT_SIZE   :: size_of(sys.Inotify_Event)
BUFFER_SIZE  :: EVENT_SIZE + MAX_NAME_LEN

InotifyEv :: struct {
	wd:     sys.Wd,
	mask:   sys.Inotify_Event_Mask,
	cookie: u32,
	len:    u32,
	name:   string,
}

EventHandler :: #type proc (
  event: InotifyEv, ch: chan.Chan(bool))

ThreadData :: struct {
  fd: sys.Fd,
  callback: EventHandler,
  channel: chan.Chan(bool),
  watchMap: map[sys.Wd]string,
  watchEvents: sys.Inotify_Event_Mask
}

read_next_event :: proc (fd: sys.Fd) -> (
  ev: InotifyEv,
  err: Err
) {
  buffer :[BUFFER_SIZE]u8
  blen :int

  blen, err = sys.read(fd, buffer[:])

  if err != .NONE {
    print.err("Error reading from file descriptor: %s", err)
    return
  }

  if blen <= 0 do return

  mem.copy(
    &ev,
    raw_data(buffer[:]),
    EVENT_SIZE
  )

  if ev.len > 0 {
    name := strings.clone_from_bytes(
      buffer[EVENT_SIZE:EVENT_SIZE + ev.len])
    ev.name = strings.trim_null(name)
  }


  bufferSize := int(EVENT_SIZE + ev.len)

  print.warn("Buffer Size: %v  || BLEN: %v || EV.LEN: %v",
    bufferSize, blen, ev.len)

  if bufferSize < blen {
    print.warn(
      "Warn: Number of bytes received exceeds " +
      "Event struct size, potentially ignored one message")
  }

  return
}

// Return a boolean for now, as posix.Errno seems
// incompatible with linux.Errno
list_dirs :: proc (
  pathname: string,
  prefix: bool = false
) -> (
  subdirs: []string,
  ok: bool = true
) {
  list: [^]^posix.dirent

  filter_fn := proc "c" (entry: ^posix.dirent) -> b32 {
    name := cstring(raw_data(entry.d_name[:]))
    not_dot := (name != ".") && (name != "..")

    return b32(not_dot && (entry.d_type == .DIR))
  }

  ret := posix.scandir(strcclone(pathname), &list, filter_fn)
  defer posix.free(list)

  if ret < 0 {
    print.err("Could not scan directory %v: %v",
      pathname, string(posix.strerror(posix.errno())))

    ok = false
    return
  }

  subdirs = make([]string, ret)

  for &entry, idx in subdirs {
    // Doesn't seem ideal, but so far this is the least
    // troublesome way I found to do it
    if prefix {
      entry = strjoin({
        pathname,
        string(cstring(raw_data(list[idx].d_name[:])))
      }, "/")
    } else {
      entry = string(cstring(raw_data(list[idx].d_name[:])))
    }

    posix.free(list[idx])
  }

  return
}

dirs_iterate :: proc (pathnames: []string) -> (
  subdirs: []string,
  ok: bool = true
) {
  for path in pathnames {
    dirs := dir_iterate(path) or_return

    if ok do subdirs = slice.concatenate([][]string{
      subdirs,
      dirs
    })
  }

  return
}

dir_iterate :: proc (pathname: string) -> (
  subdirs: []string,
  ok: bool = true
) {
  base, _ := list_dirs(pathname, true)

  for dir in base {
    dirs, _ := dir_iterate(dir)
    subdirs = slice.concatenate([][]string{subdirs, dirs})
  }

  subdirs = slice.concatenate([][]string{subdirs, base})

  return
}

async_watch :: proc (
  pathnames: []string,
  callback: EventHandler,
  events: sys.Inotify_Event_Mask = {
    .MODIFY,
    .DELETE,
    .CREATE,
    .ATTRIB
  }
) -> (
  task: thread.Thread,
  chn: chan.Chan(bool),
  err: Err
) {
  inotifyFd, inErr := sys.inotify_init1({.CLOEXEC})

  if inErr != .NONE {
    print.err(
      "An error has occurred while attempting to " +
      "open the inotify file descriptor: %s", inErr)

    err = inErr
    return
  }

  subdirs, ok := dirs_iterate(pathnames)

  if !ok {
    print.err("Could not get subdirectories!")
    return
  }

  allDirs := slicecat([][]string{ subdirs, pathnames })
  watchMap :map[sys.Wd]string

  for path in allDirs {
    wd, pErr := sys.inotify_add_watch(
      inotifyFd,
      strcclone(path),
      events)

    if pErr != .NONE {
      print.err("Failed to register watcher for \"%v\": %s",
        path, pErr)

      err = pErr
      return
    }

    watchMap[wd] = path
  }

  thr := thread.create(proc (thr: ^thread.Thread) {
    t := time.tick_now()
    data := cast(^ThreadData) thr.data
    using data

    defer sys.close(fd)
    defer free(thr.data)

    for {
      event, err := read_next_event(fd)

      if err != .NONE {
        print.err("Error reading file descriptor: %s", err)
        break
      }

      isdir := .ISDIR in event.mask

      if isdir && .CREATE in event.mask {
        path := strjoin({
          watchMap[event.wd],
          event.name
        }, "/")

        wd, pErr := sys.inotify_add_watch(
          fd,
          strcclone(path),
          watchEvents)

        if pErr != .NONE do print.err(
          "Failed to register watcher for \"%v\": %s",
          path, pErr)
        else do watchMap[wd] = path
      }

      if isdir && .DELETE in event.mask {
        err := sys.inotify_rm_watch(fd, event.wd)

        if err != .NONE do print.err(
          "Couldn't remove file watcher for \"%v\": %s",
          event.name, err)
      }

      diff := time.tick_lap_time(&t)
      ms := time.duration_milliseconds(diff)

      // Debounce by 300ms
      if ms > 300.0 do callback(event, channel)
    }
  })

  chanErr :runtime.Allocator_Error
  chn, chanErr = chan.create(
    chan.Chan(bool),
    context.allocator)

  if chanErr != .None {
    print.err("Could no allocate channel: %s", chanErr)
    // TODO: Delete inotify handle
    err = .ENOMEM
    return
  }

  data := new(ThreadData)
  data.fd = inotifyFd
  data.callback = callback
  data.channel = chn
  data.watchMap = watchMap
  data.watchEvents = events
  thr.data = data

  thread.start(thr)

  return
}

sync_watch :: proc (
  pathname: string,
  callback: EventHandler,
  events: sys.Inotify_Event_Mask = {
    .MODIFY,
    .DELETE,
    .CREATE
  }
) -> Err {
  inotifyFd, err := sys.inotify_init()

  if err != .NONE {
    print.err(
      "An error has occurred while attempting to " +
      "open the inotify file descriptor.")

    return err
  }

  _, wdErr := sys.inotify_add_watch(
    inotifyFd,
    strings.clone_to_cstring(pathname), events)

  if wdErr != .NONE {
     print.err(
      "An error has occurred while attempting to " +
      "watch the package for changes.")

    return wdErr
  }

  for {
    event, err := read_next_event(inotifyFd)

    if err != .NONE {
      print.err("Error reading file descriptor: %s", err)
      return err
    }

    //callback(event)
  }

  sys.close(inotifyFd)
  return .NONE
}

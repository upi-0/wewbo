import std/osproc
import os
import options

# from logger import log as lg
import logger as wewboLogger
from ui/log import show_log_until_complete
from strutils import strip, `%`

type
  AfterExecuteProc = proc() {.nimcall.}

  CliApplication = ref object of RootObj
    name*: string
    args*: seq[string]
    path: string
    process: Process
    available*: bool = false

  CliError = enum
    erUnknown,
    erCommandNotFound,

method failureHandler(app: CliApplication, context: CliError) {.base.} =
  # TODO: Jan langsung raise exception jir.
  raise newException(
    ValueError,
    "It looks like $# is not available in PATH or does not exist at all." % [app.name]
  )

proc check(app: CliApplication) : bool =
  try:
    discard execCmdEx(app.path)
    return true
  except OSError:
    return false

proc setUp[T: CliApplication](app: T, path: string = app.name) : T =
  app.path = path

  if defined(linux) :
    let path = execCmdEx("which " & app.name)
    wewboLogger.log.info("Using Which")
    if path.exitCode == 0:
      app.path = path.output.strip()

  app.available = app.check()

  if not app.available :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app    

proc addArg(app: CliApplication, arg: string) =
  app.args.add arg

proc execute(
  app: CliApplication,
  message: string = "Executing external app.",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc)
) : int =
  app.process = startProcess(app.path, ".", app.args)
  if clearArgs :
    app.args = @[]
  result = app.process.show_log_until_complete(message)
  if after.isSome :
    get(after)()

export
  CliApplication,
  setUp,
  addArg,
  execute
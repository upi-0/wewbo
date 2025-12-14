import std/osproc
import os
import options

from ui/log import show_log_until_complete

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
  discard

proc check(app: CliApplication) : bool =
  findExe(app.path).len >= 1

proc setUp[T: CliApplication](app: T, path: string = app.name) : T =
  app.path = path
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
  check,
  setUp,
  addArg,
  execute
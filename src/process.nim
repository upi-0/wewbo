import
  std/osproc,
  os,
  options,
  strutils,
  streams

import
  ./tui/logger as tlog,
  ./tui/base,
  illwill

type
  AfterExecuteProc* = proc() {.gcsafe, nimcall.}
  SpecialLineProc* = proc(line: string) : bool {.gcsafe, nimcall.}
  LineCallbackProc* = proc(line: string) {.gcsafe.}

  CliApplication* = ref object of RootObj
    name*: string
    args*: seq[string]
    path*: string
    process {.deprecated.}: Process
    log*: tlog.WewboLogger
    logMode*: WewboLogMode
    available* {.deprecated.}: bool = false
    specialLogLine* {.deprecated.}: SpecialLineProc

  CliError* = enum
    erUnknown,
    erCommandNotFound,

method failureHandler*(app: CliApplication, context: CliError) {.gcsafe, base.} =
  if context == erCommandNotFound:
    let msg = "'$#' Is not exist." % app.name
    raise newException(ValueError, msg)

proc check*(app: CliApplication) : bool =
  if app.name.len > 0 and app.name.fileExists():
    app.path = app.name
    return true
  app.path = app.name.findExe()
  app.path.len > 0 and app.path.fileExists()

method specialLine*(cli: CliApplication; text: string) : bool {.gcsafe, base.} =
  text.contains("\r")

method formatSpecialLine*(cli: CliApplication; text: string) : string {.gcsafe, base.} =
  text.strip()

proc setUp*[T: CliApplication](app: T) : T =
  if app.logMode != mSilent:
    app.log = useWewboLogger(app.name, mode = app.logMode)

  if not app.check() :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app

proc start*(
  app: CliApplication,
  process: Process,
  message: string,
  checkup: int = 20,
  onLine: LineCallbackProc = nil
): int =
  let
    processLogger = app.log
    strm = process.outputStream()

  var
    lineBuf = newStringOfCap(256)

  proc dispatchLine(line: string) =
    if line.len == 0:
      return
    if not onLine.isNil:
      onLine(line)
    if app.specialLine(line):
      let formatted = app.formatSpecialLine(line)
      if formatted.len > 0 and not processLogger.isNil and app.logMode == mTui:
        processLogger.setLineBuffer(processLogger.tb.height - 3, " " & formatted, bg=bgWhite, fg=fgBlack)
    elif not processLogger.isNil:
      processLogger.info(line)

  while true:
    try:
      if strm.atEnd():
        if not process.running():
          break
        checkup.sleep()
        continue

      let ch = strm.readChar()
      if ch == '\n' or ch == '\r':
        if lineBuf.len > 0:
          dispatchLine(lineBuf)
          lineBuf.setLen(0)
      else:
        lineBuf.add(ch)
    except IOError, OSError:
      if not process.running():
        break
      checkup.sleep()

  if lineBuf.len > 0:
    dispatchLine(lineBuf)

  return process.waitForExit()

proc addArg*(app: CliApplication, arg: string) =
  app.args.add arg

template logCommand(app: CliApplication) =
  if not app.log.isNil:
    app.log.info("[execute] " & app.path & " " & app.args.join(" ").strip.replace("\n", ""))

proc execute*(
  app: CliApplication,
  message: string = "Executing external app.",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc),
  onLine: LineCallbackProc = nil
) : int =
  let exePath = if app.path.len > 0 and app.path.fileExists(): app.path else: app.name.findExe()
  let process = startProcess(exePath, ".", app.args, options = {poStdErrToStdOut})
  defer: process.close()

  app.logCommand()
  result = app.start(process, message, onLine = onLine)

  if clearArgs :
    if not app.log.isNil:
      app.log.info("Clearing previous args")
    app.args = @[]

  if after.isSome :
    get(after)()

proc executeOutput*(
  app: CliApplication,
  workingDir: string = ".",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc)
): tuple[output: string, exitCode: int] =
  let process = startProcess(app.path, workingDir, app.args, options = {poStdErrToStdOut})
  defer: process.close()

  app.logCommand()  

  result.output = process.outputStream.readAll()
  result.exitCode = process.waitForExit()

  if clearArgs:
    app.args = @[]

  if after.isSome:
    get(after)()

export
  CliApplication,
  check,
  setUp,
  addArg,
  execute,
  executeOutput

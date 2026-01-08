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
  AfterExecuteProc = proc() {.nimcall.}
  SpecialLineProc* = proc(line: string) : bool {.gcsafe, nimcall.}

  CliApplication = ref object of RootObj
    name*: string
    args*: seq[string]
    path: string
    process {.deprecated.}: Process
    log: tlog.WewboLogger
    available*: bool = false
    specialLogLine*: SpecialLineProc

  CliError* = enum
    erUnknown,
    erCommandNotFound,

method failureHandler(app: CliApplication, context: CliError) {.base.} =
  discard

proc check(app: CliApplication) : bool =
  findExe(app.path).len >= 1 or findExe(app.name).len >= 1

method specialLineCB(cli: CliApplication) : SpecialLineProc {.base.} =
  (proc(x: string) : bool = x.contains("\r"))

proc setUp[T: CliApplication](app: T; path: string = app.name) : T =
  app.path = path
  app.available = app.check()
  app.specialLogLine = app.specialLineCB()
  app.log = newWewboLogger(app.name)

  if not app.available :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app    

proc start(app: CliApplication, process: Process, message: string, checkup: int = 500): int {.gcsafe.} =
  let
    isLinux = defined(linux)

  var
    outputBuffer: string
    lines: seq[string]
    stream: Stream = process.peekableOutputStream()

  proc sendLog(line: string) =    
    if app.specialLogLine(line):
      # Linux doesn't fully support this feature.
      # There may be issues related to this in the future.

      if not isLinux:
        app.log.setLineBuffer(app.log.tb.height - 3, " " & line, bg=bgWhite, fg=fgBlack)
    
    elif line != "":  
      app.log.info(line)

  proc handleOutputBufferWin(strm: Stream; place: var string) =
    let allOutputLog = strm.readAll()

    if allOutputLog.len > 0:
      place &= allOutputLog
      lines = place.split("\n")

      for line in lines:
        sendLog(line)
      
      place = lines[^1]
      lines.reset()

  proc handleOutputBufferLinux(strm: Stream; place: var string) =
    if stream.readLine(place):
      sendLog(place)

  proc handleOutputBuffer(strm: Stream; place: var string) =
    try:
      if isLinux: strm.handleOutputBufferLinux(place)
      else: strm.handleOutputBufferWin(place)
    except:
      discard # Jangan males napa lu ah  

  while true:
    if process.running():
      stream.handleOutputBuffer(outputBuffer)
      checkup.sleep()
      
    else:
      stream.handleOutputBuffer(outputBuffer)
      checkup.sleep()
      app.log.stop()

      return process.peekExitCode()  

proc addArg(app: CliApplication, arg: string) =
  app.args.add arg

proc execute(
  app: CliApplication,
  message: string = "Executing external app.",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc)
) : int =
  let process = startProcess(app.path.findExe(), ".", app.args)
  result = app.start(process, message)

  if clearArgs :
    app.args = @[]
  if after.isSome :
    get(after)()

export
  CliApplication,
  check,
  setUp,
  addArg,
  execute
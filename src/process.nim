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
  AfterExecuteProc = proc() {.gcsafe, nimcall.}
  SpecialLineProc* = proc(line: string) : bool {.gcsafe, nimcall.}

  CliApplication = ref object of RootObj
    name*: string
    args*: seq[string]
    path: string
    process {.deprecated.}: Process
    log*: tlog.WewboLogger
    logMode*: WewboLogMode
    available* {.deprecated.}: bool = false
    specialLogLine* {.deprecated.}: SpecialLineProc

  CliError* = enum
    erUnknown,
    erCommandNotFound,

method failureHandler(app: CliApplication, context: CliError) {.gcsafe, base.} =
  if context == erCommandNotFound:
    let msg = "'$#' Is not exist." % app.name
    raise newException(ValueError, msg)

proc check(app: CliApplication) : bool =
  app.path = app.name.findExe()
  app.path.fileExists()

method specialLine(cli: CliApplication; text: string) : bool {.gcsafe, base.} =
  text.contains("\r") 

proc setUp[T: CliApplication](app: T) : T =
  app.log = useWewboLogger(app.name, mode = app.logMode)

  if not app.check() :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app    

proc start(app: CliApplication, process: Process, message: string, checkup: int = 50): int =  
  let
    isLinux = defined(linux)
    processLogger = app.log

  var
    outputBuffer: string
    stream = process.peekableOutputStream()

  proc sendLog(line: string) =    
    if app.specialLine(line):
      processLogger.setLineBuffer(processLogger.tb.height - 3, " " & line.strip, bg=bgWhite, fg=fgBlack)
    
    elif line != "":  
      processLogger.info(line)

  proc handleOutputBufferWin(strm: Stream; place: var string) =
    sendLog strm.readLine()

  proc handleOutputBufferLinux(strm: Stream; place: var string) =
    place = stream.readLine()  
    place.sendLog()

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

      return process.peekExitCode()  

proc addArg(app: CliApplication, arg: string) =
  app.args.add arg

template logCommand(app: CliApplication) =
  app.log.info("[execute] " & app.path & " " & app.args.join(" ").strip.replace("\n", ""))

proc execute(
  app: CliApplication,
  message: string = "Executing external app.",
  clearArgs: bool = true,
  after: Option[AfterExecuteProc] = none(AfterExecuteProc)
) : int =
  let process = startProcess(app.path.findExe(), ".", app.args)
  
  app.logCommand()
  result = app.start(process, message)

  if clearArgs :
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

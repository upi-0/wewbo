import
  std/osproc,
  os,
  options,
  strutils,
  streams

import
  ./logger

type
  AfterExecuteProc = proc() {.nimcall.}

  CliApplication = ref object of RootObj
    name*: string
    args*: seq[string]
    path: string
    process {.deprecated.}: Process
    log*: WewboLogger
    available*: bool = false

  CliError* = enum
    erUnknown,
    erCommandNotFound,

method failureHandler(app: CliApplication, context: CliError) {.base.} =
  discard

proc check(app: CliApplication) : bool =
  findExe(app.path).len >= 1 or findExe(app.name).len >= 1

proc setUp[T: CliApplication](app: T, path: string = app.name) : T =
  app.path = path
  app.available = app.check()
  app.log = newWewboLogger(app.name)

  if not app.available :
    app.failureHandler(erCommandNotFound)
    quit(1)

  app    

proc start(app: CliApplication, process: Process, message: string, checkup: int = 500): int =
  var
    outputBuffer: string
    stream: Stream = process.outputStream()

  while true:
    if process.running():
      try:
        let available = stream.readAll()
        if available.len > 0:
          outputBuffer &= available          
          let lines = outputBuffer.split('\n')
          for i in 0..<lines.len - 1:
            app.log.info(lines[i])
          outputBuffer = lines[^1]
      except:
        discard
      
      sleep(checkup)
    else:
      try:
        let remaining = stream.readAll()
        if remaining.len > 0:
          outputBuffer &= remaining
          let lines = outputBuffer.split('\n')
          for line in lines:
            app.log.info(line)
      except:
        discard
      
      checkup.sleep()
      app.log.clear()

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
import
  paramarg, version

import
  os,
  sequtils,
  strutils,
  terminal,
  json

type
  SubCommandProc = proc(args: FullArgument) {.nimcall, gcsafe.}

  SubCommand = ref object of RootObj
    name*: string
    entry*: SubCommandProc
    help*: string
    args: FullArgument
    argOpts: seq[ArgOption]

proc newSubCommand(name: string, entry: SubCommandProc, argOpts: seq[ArgOption] = @[]; help: string = "") : SubCommand {.gcsafe.} =
  result = SubCommand(
    name: name,
    entry: entry,
    args: loadArguments(),
    argOpts: argOpts,
    help: help
  )
  result.args.add(argOpts)

proc exec(command: SubCommand, removeName: bool = true) =
  command.args.parse()
  if removeName :
    command.args.nargs.delete(0..0)
  command.entry(command.args)

proc perLine(li: array[2, string], pl: int = terminalWidth() div 3) : string =
  let
    asd = li[0]
    usd = li[1]
  if asd.len < pl :
    return asd & " ".repeat(pl - asd.len) & usd
  else :
    return asd[0 .. pl - 1] & " " & usd

proc showHelp(subCommand: SubCommand) =
  echo subCommand.help 
  echo "\nArguments:"

  for arg in subCommand.args.options :
    let
      valStr = ($arg.default).replace("\"", "")
      right = block:
        if valStr != "" : " (default: $#)" %  valStr
        else: ""

    echo repeat(" ", 3) & perLine([
      arg.flag,
      arg.help & right
    ], 13)

  echo ""

proc showHelp(subCommnads: openArray[SubCommand]) =
  echo "wewbo " & ver 
  echo "\nCommands:"

  for subCmd in subCommnads:
    echo repeat(" ", 3) & perLine([subCmd.name, subCmd.help], 13)

  echo ""

proc start(subCommands: openArray[SubCommand]) {.gcsafe.} =
  try:
    let args = commandLineParams()
    var nuhun: string

    if args.len < 1:
      subCommands.showHelp()
      return

    nuhun = args[0]

    if nuhun == "--help" or nuhun == "-h":
      subCommands.showHelp()

    else:
      for subCmd in subCommands:
        if nuhun == subCmd.name:
          if args.len == 1 or args.contains("-h") or args.contains("--help"):
            subCmd.showHelp() 
          else:  
            subCmd.exec()
          return

      assert false

  except AssertionDefect:
    # Default entry
    subCommands[0].exec(removeName = false)  

export
  SubCommand

export
  newSubCommand,
  option,
  start

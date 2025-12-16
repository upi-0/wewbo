import
  paramarg

import
  os,
  sequtils,
  strutils,
  terminal

type
  SubCommandProc = proc(args: FullArgument) {.nimcall.}

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
  echo perLine([subCommand.name, subCommand.help], 16)

  for arg in subCommand.args.options :
    echo " " & perLine([arg.flag, arg.help], 15)

proc showHelp(subCommnads: openArray[SubCommand]) =
  echo "list command: `wewbo [command][opts][narg]`\n"
  for subCmd in subCommnads:
    subCmd.showHelp()
    echo ""
  discard  

proc start(subCommands: openArray[SubCommand]) =
  try:
    let nuhun = commandLineParams()[0]
    if nuhun == "--help" or nuhun == "-h":
      subCommands.showHelp()

    else:
      for subCmd in subCommands :
        if nuhun == subCmd.name :
          subCmd.exec()
  
      assert false

  except IndexDefect:
    subCommands.showHelp()

  except AssertionDefect:
    # Default entry
    echo "Lu kesini?????"
    subCommands[0].exec(removeName = false)  

export
  SubCommand

export
  newSubCommand,
  option,
  start
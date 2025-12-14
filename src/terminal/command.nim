import
  paramarg

import
  tables,
  os,
  sequtils

type
  SubCommandProc = proc(args: FullArgument) {.nimcall.}

  SubCommand = ref object of RootObj
    name*: string
    entry*: SubCommandProc
    args: FullArgument
    argOpts: seq[ArgOption]

proc newSubCommand(name: string, entry: SubCommandProc, argOpts: seq[ArgOption]) : SubCommand {.gcsafe.} =
  SubCommand(
    name: name,
    entry: entry,
    args: loadArguments(),
    argOpts: argOpts
  )

proc options(flag: string, name: string, val: AllowedValType, default: auto = "") : ArgOption {.gcsafe.} =
  ArgOption(
    flag: flag,
    name: name,
    valType: val,
    default: convert($default, val)
  )

proc exec(command: SubCommand, removeName: bool = true) =
  command.args.add(command.argOpts)
  command.args.parse()
  if removeName :
    command.args.nargs.delete(0..0)
  command.entry(command.args)

proc start(subCommands: openArray[SubCommand]) =
  try:
    let nuhun = commandLineParams()[0]
    for subCmd in subCommands :
      if nuhun == subCmd.name :
        subCmd.exec()
        quit(0)
    assert false

  except AssertionDefect, IndexDefect:
    # Default entry
    subCommands[0].exec(removeName = false)  

export
  SubCommand

export
  newSubCommand,
  options,
  start
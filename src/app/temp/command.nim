import
  main,
  terminal/[command, paramarg]

const
  name = "temp"
  help = "Manage temp files"
  entry = tempManagement

proc tempCommand*: SubCommand =
  let  
    commands = @[
      option("--list", "list", "List Temp Files", false),
      option("--clear", "clear", "Cleat Temp Files", false)
    ]
  result = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands
  )

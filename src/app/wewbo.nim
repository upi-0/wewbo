import
  stream/command,
  player/command,
  temp/command,
  ani_dl/command

import
  terminal/command,
  tui/[base, logger],
  os

# let app = [
#   # streamCommand,
#   anidlCommand,
#   tempCommand,
#   playerCommand,
# ]

proc main* {.gcsafe.} = 
  let app = [
    streamCommand(),
    anidlCommand(),
    tempCommand(),
    playerCommand()
  ]
  try:
    app.start()

  except ref Exception:
    if not loga.logger.isNil:
      loga.logger.close()
    
    echo "ERROR: " & getCurrentExceptionMsg()

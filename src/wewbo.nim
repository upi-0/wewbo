import
  stream,
  download,
  version,
  logger

import
  terminal/[command, paramarg]

let app = [
  newSubCommand(
    "stream", stream.stream, @[
      options("-s", "source", tString, "kura"),
      options("-p", "player", tString)
    ]
  ),
  newSubCommand(
    "download", download.download, @[
      options("-s", "source", tString, "kura"),
      options("--outdir", "outdir", tString),
      options("-fps", "fps", tInt, 24),
      options("-crf", "crf", tInt, 28),
      options("--no-sub", "nsub", tBool, false)
    ]
  )
]

log.info(ver)
app.start()
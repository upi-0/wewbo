import ../tui/[ask, logger, router, utils]
import terminal

import macros

macro injectProcName*(procDef: untyped): untyped =
  procDef.expectKind(nnkProcDef)
  let
    name = procDef[0].toStrLit
    id = ident("name")
    nameDef = quote do:
      const `id` = `name`

  procDef.body.insert(0, nameDef)
  return procDef

proc inspect*(logger: WewboLogger; data: auto): void = 
  logger.info("")
  logger.info("CONT: " & $data)
  logger.info("TYPE: " & $(typeof data))

  waitFor(Key.Enter)

export ask, logger, router
export terminal
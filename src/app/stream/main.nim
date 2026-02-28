import
  ../tui, general_act

import
  extractor/all,
  terminal/paramarg

proc stream*(f: FullArgument) {.gcsafe, injectProcName.} =
  if f.nargs.len < 1:
      raise newException(ValueError, "Try: `wewbo [Anime Title]`")
    
  let (title, exName) = parseTitleAndSource(
      f.nargs[0], f["source"].getStr())

  let
    route = name.app(StreamSession)
    extractor = getExtractor(exName)

  block setUp:
    route.setSession()
    route.data = title
    route.session.ex = extractor
  
  route.selectAnime()
  illwillDeinit()

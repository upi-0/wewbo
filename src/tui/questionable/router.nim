import
  base, illwill

import  
  ../logger, ../ask

type
  RouteActionProc* = proc(prevRoute: Route): void {.gcsafe, closure.}

  RouteAction* = ref object of Questionable
    action*: RouteActionProc    

  Route* = ref object of RootObj
    title*: string
    actions*: seq[RouteAction]
    logger*: WewboLogger    

method setColour(item: RouteAction; is_current: bool) : tuple[bg: BackgroundColor; fg: ForegroundColor] =
  result.bg = if is_current: bgGreen else: bgBlack
  result.fg = if is_current: fgBlack else: fgWhite

  if item.title == "Back":
    result.fg = fgRed
    result.bg = bgBlack

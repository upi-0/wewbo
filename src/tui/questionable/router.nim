import
  base, illwill

import  
  ../logger, ../ask

type
  RouteActionProc*[T] = proc(prevRoute: Route[T]): void {.gcsafe.}

  RouteAction*[T] = ref object of Questionable
    action*: RouteActionProc[T]
    data*: string

  RouteActionError* = object of CatchableError

  Route*[T] = ref object of RootObj
    title*: string
    actions*: seq[RouteAction[T]]
    logger*: WewboLogger    
    data*: string
    session*: ptr T

proc setColour*(item: RouteAction; is_current: bool) : tuple[bg: BackgroundColor; fg: ForegroundColor] =
  result.bg = if is_current: bgGreen else: bgBlack
  result.fg = if is_current: fgBlack else: fgWhite

  if item.title == "Back":
    result.fg = fgRed
    result.bg = bgBlack

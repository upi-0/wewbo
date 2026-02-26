import
  illwill, ../base

type Questionable* {.inheritable.} = ref object of RootObj
  title*: string

method handleExceptionKey*(currentItem: Questionable; page: WewboTUI; key: Key) {.base, gcsafe.} =
  discard

method setColour*(item: Questionable; is_current: bool) : tuple[bg: BackgroundColor; fg: ForegroundColor] {.gcsafe, base.} =
  result.bg = if is_current: bgGreen else: bgBlack
  result.fg = if is_current: fgBlack else: fgWhite

method renderItem*(item: Questionable; tui: WewboTUI; is_selected: bool; row: int) : void {.base, gcsafe.} =
  var
    (bg, fg) = item.setColour(is_selected)
    pref = if is_selected: "► " else: "  "

  tui.setLine(row, pref & item.title, display=false, bg=bg, fg=fg)    

export
  base, illwill

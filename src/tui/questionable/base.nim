import
  illwill, ../base

type Questionable* {.inheritable.} = ref object of RootObj
  title*: string

method handleExceptionKey*(currentItem: Questionable; page: WewboTUI; key: Key) {.base, gcsafe.} =
  discard

method renderItem*(item: Questionable; tui: WewboTUI; is_selected: bool; row: int) : void {.base, gcsafe.} =
  var
    bg = if is_selected: bgGreen else: bgBlack
    fg = if is_selected: fgBlack else: fgWhite
    pref = if is_selected: "► " else: "  "

  tui.setLine(row, pref & item.title, display=false, bg=bg, fg=fg)    

export
  base, illwill

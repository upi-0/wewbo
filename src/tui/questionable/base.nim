import
  illwill, ../base

type Questionable* {.inheritable.} = ref object of RootObj
  title*: string

method handleExceptionKey*(currentItem: Questionable; page: WewboTUI; key: Key) {.base, gcsafe.} =
  discard

method renderItem*(item: Questionable; tui: WewboTUI; is_selected: bool; row: int) : void {.base, gcsafe.} =
  var bg: BackgroundColor = if is_selected: bgGreen else: bgBlack
  tui.setLine(row, " " & item.title, display=false, bg=bg)    

export
  base, illwill

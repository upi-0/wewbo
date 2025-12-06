import illwill, os, terminal, strutils
import asset

type
  Questionable* {.inheritable.} = ref object of RootObj
    title*: string

proc renderItems[T: Questionable](tb: var TerminalBuffer, data: openArray[T], 
                                  termWidth: int, startY: int, 
                                  selected: int, pageStart: int, pageEnd: int) =
  ## Render list items dengan highlight untuk item terpilih
  var row = startY
  
  for i in pageStart ..< pageEnd:
    let item = data[i]
    let contentLen = item.title.len + 2
    let padding = termWidth - contentLen - 2
    
    if i == selected:
      # Selected Line
      tb.write(0, row, fgCyan, "║", resetStyle)
      tb.setBackgroundColor(bgGreen)
      tb.setForegroundColor(fgBlack, bright=true)
      tb.write(1, row, "► " & item.title & " ".repeat(padding))
      tb.resetAttributes()
      tb.write(termWidth - 1, row, fgCyan, "║")
    else:
      # Normal Line
      tb.write(0, row, fgCyan, "║", fgWhite, "  " & item.title & " ".repeat(padding), fgCyan, "║")
    
    inc row

proc ask*[T: Questionable](data: seq[T], pageSize: int = terminalHeight() - 9, title: string = "Firaun makan nasi", init: bool = false, deInit: bool = false): T =
  if data.len == 0:
    raise newException(ValueError, "Data cannot be empty")
  
  var selected = 0
  var pageStart = 0
  let termWidth = terminalWidth()
  let itemsPerPage = pageSize
  const BANNER_HEIGHT = 7
  
  proc cleanup() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)
  
  if init :
    illwillInit(fullscreen=false)
    setControlCHook(cleanup)
    hideCursor()
  
  var tb = newTerminalBuffer(termWidth, terminalHeight())
  
  proc updatePageStart() =
    # Auto scroll pagination
    if selected < pageStart:
      pageStart = selected
    elif selected >= pageStart + itemsPerPage:
      pageStart = selected - itemsPerPage + 1
  
  proc render() =
    tb.clear()
    updatePageStart()
    
    # Render banner
    renderBanner(tb)
    
    # Hitung posisi dan range
    let topBorderY = BANNER_HEIGHT

    let itemsStartY = topBorderY + 1
    let pageEnd = min(pageStart + itemsPerPage, data.len)
    let bottomBorderY = itemsPerPage + 1
    
    # Render komponen
    renderTopBorder(tb, topBorderY, title=title)
    renderItems(tb, data, termWidth, itemsStartY, selected, pageStart, pageEnd)
    renderEmptyRows(tb, termWidth, itemsStartY + data.len, tb.height - 2)
    renderBottomBorder(tb, termWidth, tb.height - 1)
    
    tb.display()
  
  render()
  
  while true:
    var key = getKey()
    
    case key
    of Key.None: discard
    of Key.Up, Key.K:
      selected = if selected > 0: selected - 1 else: data.len - 1
      render()
    of Key.Down, Key.J:
      selected = if selected < data.len - 1: selected + 1 else: 0
      render()
    of Key.PageUp:
      selected = max(0, selected - itemsPerPage)
      render()
    of Key.PageDown:
      selected = min(data.len - 1, selected + itemsPerPage)
      render()
    of Key.Home:
      selected = 0
      render()
    of Key.End:
      selected = data.len - 1
      render()
    of Key.Enter, Key.Space:
      if deInit :
        illwillDeinit()
        showCursor()
      return data[selected]
    of Key.Escape, Key.Q:
      illwillDeinit()
      showCursor()
      quit(0)
    else: discard
    
    sleep(20)

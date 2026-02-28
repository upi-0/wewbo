import
  illwill, strutils

import ../version  
from terminal import eraseScreen

type
  WewboTUI* = ref object of RootObj
    tb*: TerminalBuffer
    borderColor*: illwill.ForegroundColor = fgCyan
    maxLen*: int
    head*: string = "Di Israel ada pisang keju?"
    content*: seq[string]
    currentY* : int

proc renderBanner(tui: WewboTUI) =
  let x = (tui.tb.width - 36) div 2 # Find the center cordinate

  tui.tb.write(x, 0, fgWhite, styleBright, "                        _           ")
  tui.tb.write(x, 1, fgWhite, styleBright, "                       | |          ")
  tui.tb.write(x, 2, fgWhite, styleBright, " __      _______      _| |__   ___  ")
  tui.tb.write(x, 3, fgWhite, styleBright, " \\ \\ /\\ / / _ \\ \\ /\\ / / '_ \\ / _ \\ ")
  tui.tb.write(x, 4, fgWhite, styleBright, "  \\ V  V /  __/\\ V  V /| |_) | (_) |")
  tui.tb.write(x, 5, fgWhite, styleBright, "   \\_/\\_/ \\___| \\_/\\_/ |_.__/ \\___/ ")  
  tui.tb.write(x, 6, fgWhite, styleBright, "")  

  tui.currentY = 7

proc crop(tui: WewboTUI; text: var string) =
  if text.len >= tui.tb.width - 2:
    text = text[0 .. tui.tb.width - 2 - 5]
    text &= "..."

  text = text.replace("\r", "")
  text.stripLineEnd()

proc renderBorder(tui: WewboTUI) = 
  var tl = " $# " % [tui.head]
  tui.crop(tl)

  let 
    y2 = tui.tb.height - 2
    y1 = tui.currentY + 1
    fg = tui.borderColor
    lp = (tui.tb.width div 2) - (tl.len div 2)

  tui.crop(tl)

  # Top
  tui.tb.write(fg)
  
  tui.tb.drawHorizLine(1, tui.tb.width - 2, tui.currentY, true)
  tui.tb.write(lp, tui.currentY, fgYellow, tl)

  tui.tb.write(0, tui.currentY, fg, "╔")
  tui.tb.write(tui.tb.width - 1, tui.currentY, fg, "╗")
  tui.currentY += 1
  tui.maxLen = y2 - tui.currentY

  # Right and Left
  tui.tb.drawVertLine(0, y1, y2, true)
  tui.tb.drawVertLine(tui.tb.width - 1, y1, y2, true)

  # Bottom
  tui.tb.drawHorizLine(1, tui.tb.width - 2, y2, true)
  tui.tb.write(0, y2, fg, "╚")
  tui.tb.write(tui.tb.width - 1, y2, fg, "╝")

  # Easter EGG
  tui.tb.write(0, tui.tb.height - 1, fgWhite, "upi-0/wewbo " & ver)

proc add*(tui: WewboTUI; text: string; fg: illwill.ForegroundColor) =
  tui.tb.write(2, tui.currentY, fg, text)
  tui.tb.display()
  tui.currentY += 1
  
proc setLineBuffer*(tui: WewboTUI; y: int; content: string; clear: bool = true; display: bool = true; crop: bool = true; fg: illwill.ForegroundColor = fgWhite; bg: illwill.BackgroundColor = bgBlack) =
  var text: string = content

  if crop:
    tui.crop(text)

  if clear:
    let sisa = tui.tb.width - 2 - text.len
    text = text & " ".repeat(sisa)

  tui.tb.write(1, y, fg, bg, text)

  if display:
    tui.tb.display()

proc setLine*(tui: WewboTUI; y: int; content: string; clear: bool = true; display: bool = true; crop: bool = true; fg: illwill.ForegroundColor = fgWhite; bg: illwill.BackgroundColor = bgBlack) {.inline.} =  
  tui.setLineBuffer(tui.currentY + y, content, clear, display, crop, fg, bg)

proc clear*(tui: WewboTUI) =
  for y in 0 .. terminalHeight():
    tui.setLineBuffer(y, "", fg=fgRed, bg=bgBlack, display=false)

  tui.tb.display()    

proc init*(tui: WewboTUI) =
  proc close() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

  try:
    illwillInit(true, false)
    hideCursor()
  except IllwillError:
    discard
  finally:
    tui.renderBanner()
    tui.renderBorder()
    setControlCHook(close)

  tui.tb.display()

proc close*(tui: WewboTUI) =
  tui.tb.write(fgWhite)
  illwillDeinit()
  eraseScreen()
  showCursor()

proc newWewboTUI*(head: string = ""; init: bool = true) : WewboTUI =
  result = WewboTUI(
    tb: newTerminalBuffer(terminalWidth(), terminalHeight()),
    head: head
  )
  result.init()  


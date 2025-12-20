import pkg/illwill
import ui/asset
import std/[strutils, terminal]

type WewboLogger* = ref object of RootObj
  name*: string
  height: int
  width: int
  tb: TerminalBuffer
  logs: seq[string]
  bannerHeight: int = 8

proc cleanup() {.noconv.} =
  illwillDeinit()
  showCursor()
  quit(0)    

proc newWewboLogger*(name: string = ""; height = terminalHeight(); width = terminalWidth()) : WewboLogger =
  result = WewboLogger(
    name: name,
    width: width,
    height: height,
    tb: newTerminalBuffer(width, height)
  )
  try :
    hideCursor()
    illwillInit(fullscreen=false)
    setControlCHook(cleanup)
  except IllwillError :
    discard

proc renderLogs(l: WewboLogger, color: illwill.ForegroundColor) =
  let
    areaX = l.height - (l.bannerHeight + 2)
    areaY = l.width - 2
  var
    msg: string
    msgs: seq[string]
    padding: int
    rijal = l.bannerHeight

  msgs =
    if l.logs.len >= areaX :
      l.logs[l.logs.len - areaX .. ^1]
    else :
      l.logs

  proc to(ma: string, mbg: var string) =
    mbg = ma
    if l.name != "" :
      mbg = "[$#] $#" % [l.name, ma]
    if mbg.len >= areaY :
      mbg = mbg[0 .. areaY - 5]      
    mbg.stripLineEnd()

  for message in msgs :
    message.to(msg)
    padding = l.width - msg.len - 4
    l.tb.write(0, rijal, fgCyan, "║", color, "  " & msg & " ".repeat(padding), fgCyan, "║")
    rijal += 1
  
  for i in rijal .. l.height - 2 :
    l.tb.write(0, i, fgCyan, "║" & " ".repeat(l.width - 2) & "║")

proc clear*(l: WewboLogger) =
  l.logs = @[]

proc render(l: WewboLogger, textColor: illwill.ForeGroundColor = fgWhite) =
  l.tb.renderBanner()
  l.tb.renderTopBorder(7)
  l.renderLogs(textColor)
  l.tb.renderBottomBorder(l.width, l.height - 1)
  l.tb.display()

proc info*(l: WewboLogger, text: string) =
  l.logs.add(text)
  l.render()

proc warn*(l: WewboLogger, text: string) =
  l.logs.add(text)
  l.render(fgYellow)

proc error*(l: WewboLogger, text: string) =
  l.logs.add(text)
  l.render(fgRed)

var log* = newWewboLogger()
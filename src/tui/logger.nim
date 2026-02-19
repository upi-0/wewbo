import
  options, strutils, marshal

import
  pkg/illwill

import
  base, utils

type
  ContentPTR* = ptr seq[string]
  
  LogContainer* = tuple[
    logger: WewboLogger,
    content: seq[string],
  ]

  WewboLogMode* = enum
    mTui = "tui",
    mEcho = "echo",
    mSilent = "silent"

  WewboLogger* = ref object of WewboTUI
    name*: string
    height*: int
    width*: int
    logs*: seq[string]
    bannerHeight*: int = 8
    konten*: Option[ContentPTR]
    saveLog: bool = false
    mode: WewboLogMode

  WewboLogStyle = tuple[
    fg: illwill.ForegroundColor,
    bg: illwill.BackgroundColor
  ]    

const
  WEWBO_TEXT_STYLE_SEPERATOR = "|||"
  WEWBO_DEFAULT_STYLE = (fg: illwill.fgWhite, bg: illwill.bgBlack)

let
  loga* = cast[ptr LogContainer](alloc0 sizeof LogContainer)

func detectLogMode*(s: string) : WewboLogMode {.noSideEffect.} =
  for mode in WewboLogMode:
    if s == $mode:
      return mode

  return WewboLogMode.mTui

proc newWewboLogger*(
  name: string;
  height = terminalHeight();
  width = terminalWidth();
  konten: Option[ContentPTR] = none(ContentPTR);
  saveLog: bool = false;
  mode: WewboLogMode = mTui
) : WewboLogger {.gcsafe.} =  
  result = WewboLogger(
    name: name,
    head: name,
    width: width,
    height: height,
    tb: newTerminalBuffer(width, height),
    konten: konten,
    saveLog: saveLog,
    mode: mode
  )

  if saveLog:
    result.logs = newSeq[string](result.maxLen)

  case mode
  of mTui:
    result.init()
  else:
    discard  
  
proc useWewboLogger*(
  name: string;
  height = terminalHeight();
  width = terminalWidth();
  mode: WewboLogMode = mTui
) : WewboLogger {.gcsafe.} =
  loga.logger.reset()
  loga.logger = newWewboLogger(
    name,
    height,
    width,
    some(addr loga.content),
    false,
    mode
  )
  loga.logger

proc logAddress(l: WewboLogger) : ContentPTR =
  if l.konten.isSome:
    return l.konten.get

  return addr l.logs

proc logz*(l: WewboLogger) : seq[string] =
  l.logAddress()[]

proc parseStyle(text: string): tuple[text: string, style: WewboLogStyle] =
  if text.contains(WEWBO_TEXT_STYLE_SEPERATOR) :
    let
      param = WEWBO_TEXT_STYLE_SEPERATOR
      rawStyle = text[text.find(param) + param.len .. ^1]
    
    return (text: text.replace(rawStyle).replace(WEWBO_TEXT_STYLE_SEPERATOR), style: to[WewboLogStyle](rawStyle))

  (text: text, style: WEWBO_DEFAULT_STYLE)

proc renderLogs(l: WewboLogger) =
  let
    mf = l.logz

  var
    rijal = l.maxLen
    idx = rijal
    showedLog = mf

  if showedLog.len >= l.maxLen:
    showedLog = mf[mf.len - l.maxLen .. ^1]

  var
    text: string
    style: WewboLogStyle

  for log in showedLog:
    idx = l.maxLen - rijal
    (text, style) = log.parseStyle()

    l.setLine(idx, " " & text, display=false, bg=style.bg, fg=style.fg)
    dec rijal

template addLog(l: WewboLogger; text: string) =
  l.logAddress()[].add(text)

proc render(l: WewboLogger; text: string; styleColor: WewboLogStyle = WEWBO_DEFAULT_STYLE) =
  l.addLog(text & "|||" & $$styleColor)
  case l.mode
  of mTui:
    l.renderLogs()
    l.tb.display()
  of mEcho:
    echo text
  of mSilent:
    discard

proc color*(fg: ForegroundColor = WEWBO_DEFAULT_STYLE.fg; bg: BackgroundColor = WEWBO_DEFAULT_STYLE.bg): WewboLogStyle {.inline.} =
  (fg: fg, bg: bg)

proc text*(l: WewboLogger; text: string; color: WewboLogStyle) {.inline.} =
  l.render(text, color)

proc info*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc warn*(l: WewboLogger, text: string) {.inline.} =
  l.render(text, color(fgYellow))

proc error*(l: WewboLogger, text: string) =
  l.render(text, color(fgRed))
  l.render("[?] Enter to continue", color(fgYellow))

  waitFor(Key.Enter)

proc stop*(l: WewboLogger; save: bool = false) =
  if l.mode == mTui:
    l.clear()

  if save:
    writeFile("wewbo.log", join(l.logz, "\n"))

  if l.konten.isNone:
    l.logAddress()[].reset()

when isMainModule:
  discard

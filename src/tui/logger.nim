import
  terminal, options, strutils

import
  pkg/illwill

import
  base

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

proc renderLogs(l: WewboLogger; content: seq[string]) =
  let
    mf = l.logz

  var
    rijal = l.maxLen
    idx = rijal
    showedLog = mf

  if showedLog.len >= l.maxLen:
    showedLog = mf[mf.len - l.maxLen .. ^1]

  for log in showedLog:
    idx = l.maxLen - rijal
    l.setLine(idx, " " & log, display=false)
    dec rijal

proc renderLogs(l: WewboLogger) {.inline.} =
  l.renderLogs(l.logz)

proc addLog(l: WewboLogger; text: string) {.inline.} =
  l.logAddress()[].add(text)

proc render(l: WewboLogger; text: string; textColor: illwill.ForeGroundColor = fgWhite) =
  l.addLog(text)
  case l.mode
  of mTui:
    l.renderLogs()
    l.tb.display()
  of mEcho:
    echo text
  of mSilent:
    discard

proc info*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc warn*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc error*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc stop*(l: WewboLogger; save: bool = false) =
  if l.mode == mTui:
    l.clear()

  if save:
    writeFile("wewbo.log", join(l.logz, "\n"))

  if l.konten.isNone:
    l.logAddress()[].reset()

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

  WewboLogger* = ref object of WewboTUI
    name*: string
    height*: int
    width*: int
    logs*: seq[string]
    bannerHeight*: int = 8
    konten*: Option[ContentPTR]
    saveLog: bool = false

let
  loga* = cast[ptr LogContainer](alloc0 sizeof LogContainer)

proc newWewboLogger*(name: string; height = terminalHeight(); width = terminalWidth(); konten: Option[ContentPTR] = none(ContentPTR); saveLog: bool = false) : WewboLogger {.gcsafe.} =  
  result = WewboLogger(
    name: name,
    head: name,
    width: width,
    height: height,
    tb: newTerminalBuffer(width, height),
    konten: konten,
    saveLog: saveLog
  )

  if saveLog:
    result.logs = newSeq[string](result.maxLen)

  result.init()

proc useWewboLogger*(name: string; height = terminalHeight(); width = terminalWidth()) : WewboLogger {.gcsafe.} =
  loga.logger.reset()
  loga.logger = newWewboLogger(
    name,
    height,
    width,
    some(addr loga.content)
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
  l.renderLogs()
  l.tb.display()

proc info*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc warn*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc error*(l: WewboLogger, text: string) {.inline.} =
  l.render(text)

proc stop*(l: WewboLogger; save: bool = false) =
  assert l.konten.isNone

  if save:
    writeFile("wewbo.log", join(l.logz, "\n"))

  l.logAddress()[].reset()
  l.clear()

from math import round
import streams
import strutils
import std/[macros]
import illwill
import terminal

macro getField*(obj: object, fieldName: static string): untyped =
  nnkDotExpr.newTree(obj, ident(fieldName))

func isDigit*(target: float) : bool =
  target == target.round

func find_episode*(find: int, total_episode: int, episode_per_page: int) : int =
  var
    total_page = total_episode / episode_per_page
    rijal = find / episode_per_page    

  if not isDigit(total_page) :
    total_page += 1

  return int(round total_page) - int(round rijal)

template cetak*(content: string) =
  var
    stream: FileStream
    tulis: string

  try :
    stream = newFileStream("log.txt", fmRead)
    tulis = stream.readAll & content
    stream.close()
  except:  
    tulis = content

  try:
    stream = newFileStream("log.txt", fmWrite)
    stream.write(tulis & "\n")
    stream.close()

  except:
    discard

func getBetween*(text: string, start: string, endd: string): string =
  try:
    let
      stato = text.find(start) + start.len
      smento = text[stato .. text.len - 1]
      endoo = smento.find(endd) - 1

    return smento[0 .. endoo]

  except RangeDefect:
    return ""

func forcedGetBetween*(text: string, prefsuf: openArray[array[2,
    string]]): string =
  var
    hasil: string

  for ps in prefsuf:
    hasil = text.getBetween(ps[0], ps[1])
    if hasil.len > 0:
      return hasil

  return ""

func getAttribute*(text: string, start: string, endo: string = ","): string =
  var rules = @[
    [start, endo],
    [start, "\n"]
  ]
  text.forcedGetBetween(rules)

proc contains*(text: string, target: openArray[string]) : bool =
  for tgt in target :
    if text.contains(tgt) :
      return true
  false

proc getAfter*(text: string, start: string): string =
  var stato = text.find(start) + start.len
  return text[stato .. text.len - 1]

proc exit*(s: int = 0) {.noconv, deprecated.} =
  try:
    illwillDeinit()
  except:
    discard
  finally:
    showCursor() 
    quit(0)
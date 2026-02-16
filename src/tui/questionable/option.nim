import
  sequtils, json, strutils, sugar

import
  ./base, ../ask,
  ../../opt

type
  OptionValuedQuestionable* {.inheritable.} = ref object of Questionable
    value*: string
    key*: string

  OptionStringQuestionable {.final.} = ref object of OptionValuedQuestionable

  OptionQuestionable {.final.} = ref object of OptionValuedQuestionable
    options*: seq[string]
    optionIdx*: int

proc get*[T: OptionValuedQuestionable](options: seq[T]; key: string) : string =
  for opt in options:
    if opt.key == key:
      return opt.value

proc once(title, key: var string) =
  if title == "":
    title = key
  if key == "":
    key = title

proc optionQ*(options: openArray[string]; title: string = ""; key: string = "") : OptionQuestionable =
  result = OptionQuestionable()
  result.options = options.toSeq
  result.title = title
  result.key = key

  once(result.title, result.key)

proc optionQ*(default: string; title: string = ""; key: string = "") : OptionStringQuestionable =
  result = OptionStringQuestionable()
  result.title = title
  result.key = key
  result.value = default

  once(result.title, result.key) 

proc setColour(item: OptionValuedQuestionable; is_current: bool) : tuple[bg: BackgroundColor; fg: ForegroundColor] =
  result.bg = if is_current: bgBlack else: bgBlack
  result.fg = if is_current: fgYellow else: fgWhite

method renderItem*(item: OptionQuestionable; tui: WewboTUI; is_current: bool; row: int) : void = 
  let
    (bg, fg) = item.setColour(is_current)    
    itemm = item.options[item.optionIdx]
    val = "$# <>" % [itemm, $(item.optionIdx + 1)]
    tit = item.title
    padd = tui.tb.width - 4 - tit.len - val.len
    text = tit & repeat(" ", padd) & val

  item.value = itemm
  tui.setLine(row, " " & text, display=false, fg=fg, bg=bg)

method handleExceptionKey*(currentItem: OptionQuestionable; tui: WewboTUI; key: Key) : void =
  case key
  of Key.Right:
    if currentItem.options.len <= currentItem.optionIdx + 1:
      currentItem.optionIdx = 0
    else:
      inc currentItem.optionIdx
  of Key.Left:
    if currentItem.optionIdx <= 0:
      currentItem.optionIdx = currentItem.options.len - 1
    else:
      dec currentItem.optionIdx    
  else:
    discard  

method renderItem*(item: OptionStringQuestionable; tui: WewboTUI; is_current: bool; row: int) : void =
  let
    (bg, fg) = item.setColour(is_current)    
    val = item.value
    tit = item.title
    padd = tui.tb.width - 7 - tit.len - val.len
    text = tit & repeat(" ", padd) & val & " ::"

  tui.setLine(row, " " & text, fg=fg, bg=bg)    

method handleExceptionKey*(currentItem: OptionStringQuestionable; tui: WewboTUI; key: Key) : void = 
  case key
  of Key.Space:
    currentItem.value &= " "
  of Key.Backspace, Key.CtrlH:
    if currentItem.value != "":
      currentItem.value = currentItem.value[0 .. ^2]
  of Key.Dot:
    currentItem.value &= "."
  of Key.Right, Key.Left:
    discard  

  else:
    currentItem.value &= ($key).toLowerAscii

proc ask*(plate: var OptionJson; title: string = "Select Option"): void =
  var cont: seq[OptionValuedQuestionable]
  
  # To OptionValuedQuestionable
  for (key, val) in plate.pairs():
    case val.kind
    of JString:
      cont.add optionQ(val.getStr(), key=key)
    of JArray:
      cont.add optionQ(val.getElems().map(x => x.getStr()), key=key)
    of JInt:
      cont.add optionQ($val.getInt(), key=key)  
    else:
      discard  

  # To Json
  discard cont.ask(title)
  
  for key in plate.keys:
    plate[key] = %cont.get(key)

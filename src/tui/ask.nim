import
  os, illwill, sequtils, json, sugar, tables, strutils

import
  base,
  questionable/[
    base,
    option
  ]

import
  ../opt

proc `[]`*[T: Questionable](inputs: openArray[T]; key: string): T =
  for input in inputs:
    if input.title == key:
      return input

  raise newException(ValueError, "Value not found: '$#'" % key)

proc ask*[T: Questionable](input: seq[T]; title: string = "Anto make kacamata") : T {.gcsafe.} =
  let 
    page = newWewboTUI(title)
    itemsPerPage = terminalHeight() - 10

  var 
    pageEnd, pageStart: int
    selectedContentIdx, contentIdx: int

  proc updatePageStart =
    if selectedContentIdx < pageStart:
      pageStart = selectedContentIdx
    elif selectedContentIdx >= pageStart + itemsPerPage:
      pageStart = selectedContentIdx - itemsPerPage + 1      
    pageEnd = min(pageStart + itemsPerPage, input.len)

  proc renderItems =
    updatePageStart()      

    for i in pageStart ..< pageEnd:
      input[i].renderItem(page, i == selectedContentIdx, contentIdx)
      contentIdx.inc

    page.tb.display()
    contentIdx.reset()
    pageEnd.reset()

  renderItems()

  while true:
    var key = getKey()
    case key
    of Key.Up:
      selectedContentIdx = if selectedContentIdx > 0: selectedContentIdx - 1 else: input.len - 1
      renderItems()
    of Key.Down:
      selectedContentIdx = if selectedContentIdx < input.len - 1: selectedContentIdx + 1 else: 0
      renderItems()
    of Key.Home:
      selectedContentIdx = 0
      renderItems()
    of Key.End:
      selectedContentIdx = input.len - 1
      renderItems()
    of Key.Left, Key.LeftBracket:
      return
    of Key.Enter, Key.Right, Key.RightBracket:
      return input[selectedContentIdx]      
    of Key.Escape:
      illwillDeinit()
      showCursor()
      quit(0)
    of Key.None:
      discard
    else:
      input[selectedContentIdx].handleExceptionKey(page, key)
      renderItems()

    sleep(20)

proc putEnum*[T: Questionable](plate: var OptionJson; inputs: seq[T]; key: string): void =
  var res: seq[string]
  
  for input in inputs:
    res.add(input.title)

  plate.putEnum(res, key)  

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

export base

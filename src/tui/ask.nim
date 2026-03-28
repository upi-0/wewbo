import
  os, illwill, sequtils, json, sugar, tables, strutils, logger

import
  base,
  questionable/[
    base,
    option,
    router
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
    localLog = useWewboLogger("ask")
    page = newWewboTUI(title)
    itemsPerPage = terminalHeight() - 10

  localLog.info("[ASK.$#] input len: $#" % [title, $input.len])

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

  if input.len == 1:
    return result

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
    of Key.Enter:
      block setResult:
        result = input[selectedContentIdx]
        localLog.info("[ASK.$#] select: $# | title: $#" % [title, $selectedContentIdx, result.title])
      return result
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

export base

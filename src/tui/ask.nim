import
  os, illwill, sequtils

import
  questionable/base as qbase,
  base

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
    of Key.Enter:
      return input[selectedContentIdx]      
    of Key.None:
      discard
    else:
      input[selectedContentIdx].handleExceptionKey(page, key)
      renderItems()

    sleep(20)

export
  base, qbase

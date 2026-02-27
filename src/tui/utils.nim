import illwill
from os import sleep
from strutils import
  replace,
  stripLineEnd

proc waitFor*(key: Key; sleep: int = 50): void =
  var keyInput: Key
  try:
    while true:
      keyInput = getKey()
      if keyInput == key:
        break
      sleep.sleep()
  
  except IllwillError:   
    discard

proc crop*(text: var string) =
  let width = terminalWidth()
  if text.len >= width - 2:
    text = text[0 .. width - 2 - 5]
    text &= "..."

  text = text.replace("\r", "")
  text.stripLineEnd()

export illwill

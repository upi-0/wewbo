import illwill

from os import
  sleep

from tables import
  Table,
  hasKey,
  `[]=`,
  `[]`

from strutils import
  replace,
  stripLineEnd,
  startsWith,
  toLowerAscii

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

proc commonDict(): Table[Key, string] {.compileTime.} =
  result[Key.Slash] = "/"
  result[Key.Space] = " "
  result[Key.Dot] = "."
  result[Key.Comma] = ","
  result[Key.Semicolon] = ";"
  result[Key.Backslash] = "\\"
  result[Key.Minus] = "-"
  result[Key.LeftBracket] = "["
  result[Key.RightBracket] = "]"
  result[Key.GraveAccent] = "`"
  result[Key.Equals] = "="
  result[Key.DoubleQuote] = "\""
  result[Key.SingleQuote] = "'"
  result[Key.Dollar] = "$"
  result[Key.One] = "1"      
  result[Key.Two] = "2"      
  result[Key.Three] = "3"    
  result[Key.Four] = "4"     
  result[Key.Five] = "5"     
  result[Key.Six] = "6"      
  result[Key.Seven] = "7"    
  result[Key.Eight] = "8"    
  result[Key.Nine] = "9"     
  result[Key.Zero] = "0"     
  result[Key.Tilde] = "~"
  result[Key.At] = "@"
  result[Key.Hash] = "#"
  result[Key.Percent] = "%"
  result[Key.Caret] = "^"
  result[Key.Ampersand] = "&"
  result[Key.Asterisk] = "*"
  result[Key.LeftParen] = "("
  result[Key.RightParen] = ")"
  result[Key.Underscore] = "_"
  result[Key.Plus] = "+"
  result[Key.ExclamationMark] = "!"
  result[Key.QuestionMark] = "?"
  result[Key.LessThan] = "<"
  result[Key.GreaterThan] = ">"
  result[Key.Colon] = ":"
  result[Key.Pipe] = "|"
  result[Key.RightBrace] = "}"
  result[Key.LeftBrace] = "{"

const keysDict = commonDict()

proc toStr*(key: Key): string =
  if keysDict.hasKey(key):
    keysDict[key]
  elif ($key).startsWith("Shift"):
    $($key)[^1]
  else:
    ($key).toLowerAscii()

proc crop*(text: var string) =
  let width = terminalWidth()
  if text.len >= width - 2:
    text = text[0 .. width - 2 - 5]
    text &= "..."

  text = text.replace("\r", "")
  text.stripLineEnd()

export illwill

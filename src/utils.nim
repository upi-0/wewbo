from math import round
import streams
import strutils
import std/[macros, json, unicode]
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

type
  JsObjectError* = object of ValueError

func parseJsValue(s: string, i: var int, varsAsNull: bool = true): JsonNode

func skipWhitespaceAndComments(s: string, i: var int) =
  while i < s.len:
    if s[i] in {' ', '\t', '\r', '\n'}:
      inc i
    elif i + 1 < s.len and s[i] == '/' and s[i+1] == '/':
      i += 2
      while i < s.len and s[i] != '\n':
        inc i
      if i < s.len and s[i] == '\n':
        inc i
    elif i + 1 < s.len and s[i] == '/' and s[i+1] == '*':
      i += 2
      while i + 1 < s.len and not (s[i] == '*' and s[i+1] == '/'):
        inc i
      if i + 1 < s.len:
        i += 2
    else:
      break

func parseJsString(s: string, i: var int): string =
  let quote = s[i]
  inc i
  result = ""
  while i < s.len and s[i] != quote:
    if s[i] == '\\':
      inc i
      if i >= s.len: break
      case s[i]
      of 'n': result.add '\n'
      of 'r': result.add '\r'
      of 't': result.add '\t'
      of 'b': result.add '\b'
      of 'f': result.add '\f'
      of '\\': result.add '\\'
      of '/': result.add '/'
      of '"': result.add '"'
      of '\'': result.add '\''
      of '`': result.add '`'
      of 'u':
        if i + 4 < s.len:
          try:
            let code = parseHexInt(s[i+1 .. i+4])
            result.add toUTF8(Rune(code))
            i += 4
          except:
            result.add "\\u"
        else:
          result.add "\\u"
      else:
        result.add s[i]
      inc i
    else:
      result.add s[i]
      inc i
  if i < s.len and s[i] == quote:
    inc i

func parseJsIdentifier(s: string, i: var int): string =
  let start = i
  while i < s.len and (s[i] in {'a'..'z', 'A'..'Z', '0'..'9', '_', '$', '-'}):
    inc i
  result = s[start ..< i]

func parseJsNumber(s: string, i: var int): JsonNode =
  let start = i
  if s[i] in {'+', '-'}:
    inc i
  
  if i + 1 < s.len and s[i] == '0' and (s[i+1] in {'x', 'X'}):
    i += 2
    let hexStart = i
    while i < s.len and s[i] in {'0'..'9', 'a'..'f', 'A'..'F'}:
      inc i
    let val = parseHexInt(s[hexStart ..< i])
    let finalVal = if s[start] == '-': -val else: val
    return newJInt(finalVal)

  var isFloat = false
  while i < s.len and s[i] in {'0'..'9'}:
    inc i
  if i < s.len and s[i] == '.':
    isFloat = true
    inc i
    while i < s.len and s[i] in {'0'..'9'}:
      inc i
  if i < s.len and s[i] in {'e', 'E'}:
    isFloat = true
    inc i
    if i < s.len and s[i] in {'+', '-'}:
      inc i
    while i < s.len and s[i] in {'0'..'9'}:
      inc i

  let raw = s[start ..< i]
  if isFloat or raw.contains('.'):
    var floatStr = raw
    if floatStr.startsWith("."): floatStr = "0" & floatStr
    elif floatStr.startsWith("+."): floatStr = "0" & floatStr[1..^1]
    elif floatStr.startsWith("-."): floatStr = "-0" & floatStr[1..^1]
    return newJFloat(parseFloat(floatStr))
  else:
    try:
      return newJInt(parseBiggestInt(raw))
    except:
      return newJFloat(parseFloat(raw))

func parseJsObjectNode(s: string, i: var int, varsAsNull: bool = true): JsonNode =
  result = newJObject()
  inc i # skip '{'
  while true:
    skipWhitespaceAndComments(s, i)
    if i >= s.len:
      raise newException(JsObjectError, "Unclosed object in JS")
    if s[i] == '}':
      inc i
      return
    
    var key = ""
    if s[i] in {'"', '\'', '`'}:
      key = parseJsString(s, i)
    elif s[i] in {'a'..'z', 'A'..'Z', '_', '$', '0'..'9'}:
      key = parseJsIdentifier(s, i)
    else:
      raise newException(JsObjectError, "Invalid key at position " & $i & ": " & s[i])
    
    skipWhitespaceAndComments(s, i)
    var val: JsonNode
    if i < s.len and s[i] == ':':
      inc i # skip ':'
      val = parseJsValue(s, i, varsAsNull)
    elif i < s.len and s[i] in {',', '}'}:
      # ES6 shorthand property: {nama} -> {nama: nama} (variable reference)
      val = if varsAsNull: newJNull() else: newJString(key)
    else:
      raise newException(JsObjectError, "Expected ':' or ',' after key '" & key & "' at position " & $i)

    result[key] = val
    
    skipWhitespaceAndComments(s, i)
    if i < s.len and s[i] == ',':
      inc i
      skipWhitespaceAndComments(s, i)
      if i < s.len and s[i] == '}': # trailing comma
        inc i
        return
    elif i < s.len and s[i] == '}':
      inc i
      return
    else:
      raise newException(JsObjectError, "Expected ',' or '}' at position " & $i)

func parseJsArrayNode(s: string, i: var int, varsAsNull: bool = true): JsonNode =
  result = newJArray()
  inc i # skip '['
  while true:
    skipWhitespaceAndComments(s, i)
    if i >= s.len:
      raise newException(JsObjectError, "Unclosed array in JS")
    if s[i] == ']':
      inc i
      return
    
    let val = parseJsValue(s, i, varsAsNull)
    result.add val
    
    skipWhitespaceAndComments(s, i)
    if i < s.len and s[i] == ',':
      inc i
      skipWhitespaceAndComments(s, i)
      if i < s.len and s[i] == ']': # trailing comma
        inc i
        return
    elif i < s.len and s[i] == ']':
      inc i
      return
    else:
      raise newException(JsObjectError, "Expected ',' or ']' at position " & $i)

func parseJsValue(s: string, i: var int, varsAsNull: bool = true): JsonNode =
  skipWhitespaceAndComments(s, i)
  if i >= s.len:
    raise newException(JsObjectError, "Unexpected end of input")
  
  case s[i]
  of '{':
    return parseJsObjectNode(s, i, varsAsNull)
  of '[':
    return parseJsArrayNode(s, i, varsAsNull)
  of '"', '\'', '`':
    return newJString(parseJsString(s, i))
  of '0'..'9', '-', '+':
    return parseJsNumber(s, i)
  of '.':
    if i + 1 < s.len and s[i+1] in {'0'..'9'}:
      return parseJsNumber(s, i)
    else:
      raise newException(JsObjectError, "Unexpected '.' at position " & $i)
  else:
    if s[i] in {'a'..'z', 'A'..'Z', '_', '$'}:
      let id = parseJsIdentifier(s, i)
      case id
      of "true": return newJBool(true)
      of "false": return newJBool(false)
      of "null", "undefined", "NaN", "Infinity": return newJNull()
      else:
        # Variable reference (e.g. {nama: nama} -> {"nama": null})
        if varsAsNull:
          return newJNull()
        else:
          return newJString(id)
    else:
      raise newException(JsObjectError, "Unexpected token '" & s[i] & "' at position " & $i)

func parseJsObject*(text: string, varsAsNull: bool = true): JsonNode =
  var start = 0
  skipWhitespaceAndComments(text, start)
  var clean = text
  if start < text.len and text[start] notin {'{', '['}:
    if text.contains(":"):
      clean = "{" & text & "}"

  var i = 0
  result = parseJsValue(clean, i, varsAsNull)
  skipWhitespaceAndComments(clean, i)
  if i < clean.len and clean[i] == ';':
    inc i
    skipWhitespaceAndComments(clean, i)

func jsToJson*(text: string, pretty: bool = false, varsAsNull: bool = true): string =
  let node = parseJsObject(text, varsAsNull = varsAsNull)
  if pretty:
    return pretty(node)
  return $node

func jsObjectToJson*(text: string, pretty: bool = false, varsAsNull: bool = true): string =
  jsToJson(text, pretty, varsAsNull = varsAsNull)

func encodeJsObject*(text: string, pretty: bool = false, varsAsNull: bool = true): string =
  jsToJson(text, pretty, varsAsNull = varsAsNull)

proc exit*(s: int = 0) {.noconv, deprecated.} =
  try:
    illwillDeinit()
  except:
    discard
  finally:
    showCursor() 
    quit(0)
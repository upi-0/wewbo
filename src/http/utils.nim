import
  json, strutils, uri

import ../utils

func addSlash(i: string): string =
  if not i.endsWith("/"): i & "/"
  else: i

func detectHost*(url: string): string {.inline.} =
  getBetween(url.addSlash(), "https://", "/")

func jsonToForm*(j: JsonNode): string =
  var parts: seq[string] = @[]

  for k, v in j.pairs:
    let key = encodeUrl(k)
    let value =
      case v.kind
      of JString: encodeUrl(v.getStr)
      of JInt: encodeUrl($v.getInt)
      of JFloat: encodeUrl($v.getFloat)
      of JBool: encodeUrl($v.getBool)
      else: encodeUrl($v)

    parts.add(key & "=" & value)

  result = parts.join("&")

when isMainModule:
  assert addSlash("youtube.com") == "youtube.com/"
  assert addSlash("youtube.com/") == "youtube.com/"
  assert detectHost("https://youtube.com") == "youtube.com"
  assert detectHost("https://youtube.com/watch?q=keyword") == "youtube.com"

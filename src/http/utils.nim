import strutils, ../utils

func addSlash(i: string): string =
  if not i.endsWith("/"): i & "/"
  else: i

func detectHost*(url: string): string {.inline.} =
  getBetween(url.addSlash(), "https://", "/")

when isMainModule:
  assert addSlash("youtube.com") == "youtube.com/"
  assert addSlash("youtube.com/") == "youtube.com/"
  assert detectHost("https://youtube.com") == "youtube.com"
  assert detectHost("https://youtube.com/watch?q=keyword") == "youtube.com"

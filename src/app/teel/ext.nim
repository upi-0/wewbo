import
  strutils, tables, sequtils

import
  types  

proc parseASS*(content: string): seq[LineContent] =
  var
    parts: seq[string]
    idx: int
    
  for line in content.splitLines:
    if line.startsWith("Dialoge:"):
      parts = line.split(",", 9)
      if parts.len == 10:
        result.add((idx: idx, text: parts[9]))
    inc idx

proc parseVTT*(content: string): seq[LineContent] =
  var
    idx: int

  for line in content.splitLines:
    if not line.contains("-->") and line != "" and line != "WEBVTT":
      result.add((idx: idx, text:line))
    inc idx

proc substitleExtHandler: Table[string, ParserProc] =
  result[".vtt"] = parseVTT
  result[".ass"] = parseASS

const
  handlers* = substitleExtHandler()
  availableHandlers* = handlers.keys().toSeq()

export
  `[]`

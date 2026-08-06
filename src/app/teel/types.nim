type
  LineContent* = tuple[
    idx: int,
    text: string
  ]

  ChunkedLineContent* = tuple[
    idxes: seq[int],
    translatedLines: seq[string],
    rawLines: seq[string]
  ]

  ParserProc* = proc(content: string): seq[LineContent] {.gcsafe.}

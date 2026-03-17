from strutils import
  replace,
  toLowerAscii,
  splitWhitespace,
  contains

from algorithm import
  sort,
  SortOrder

proc find*(inputs: openArray[string]; key: string): seq[string] =
  type
    Batch = tuple[result: string, score: int]

  let query = block:
    key
      .replace("%20", " ")
      .replace("+", " ")
      .toLowerAscii()
      .splitWhiteSpace()
      
  var
    batch: Batch
    res: seq[Batch]

  for input in inputs:
    batch = (input.toLowerAscii(), 0)
    
    for word in query:
      if batch.result.contains(word):
        batch.score += 1

    if batch.score > 0:
      res.add batch

  res.sort(order=Descending)

  for r in res:
    result.add r.result

when isMainModule:
  const cari = ["uma musume", "slow loop", "slow start", "one punch man"]

  block example:
    assert cari.find("slow start") == @[cari[2], cari[1]]
    assert cari.find("one man") == @[cari[^1]]
    assert cari.find("naruto") == @[]

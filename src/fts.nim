from strutils import
  replace,
  toLowerAscii,
  splitWhitespace,
  contains

from algorithm import
  sort,
  SortOrder

type
  Batch[T] = tuple[result: string, score: int, inputObject: T]
  GetKeyProc[T] = proc(inputObject: T): string {.gcsafe.}

proc c[T](inputObject: T) : string {.gcsafe.} =
  when inputObject is string:
    return inputObject

proc find*[T](inputs: openArray[T]; key: string; getKey: GetKeyProc[T] = c[T]): seq[T] =
  let query = block:
    key
      .replace("%20", " ")
      .replace("+", " ")
      .toLowerAscii()
      .splitWhiteSpace()
      
  var
    batch: Batch[T]
    batchs: seq[Batch[T]]

  for input in inputs:
    batch = (getKey(input).toLowerAscii(), 0, input)
    
    for word in query:
      if batch.result.contains(word):
        batch.score += 1

    if batch.score > 0:
      batchs.add batch

  batchs.sort(order=Descending)

  for bch in batchs:
    result.add bch.inputObject

when isMainModule:
  block example1:
    const cari = ["uma musume", "slow loop", "slow start", "one punch man"]
    assert cari.find("slow start") == @[cari[2], cari[1]]
    assert cari.find("one man") == @[cari[^1]]
    assert cari.find("naruto") == @[]

  block example2:
    const subhanallah = [("uma musume", "1"), ("slow loop", "jokowi"), ("slow start", "2"), ("one punch man", "2")]
    proc getStr(inputObject: tuple[title: string, gajelas: string]) : string = inputObject.title
    assert subhanallah.find("slow start", getStr) == @[subhanallah[2], subhanallah[1]]
    assert subhanallah.find("one man", getStr) == @[subhanallah[^1]]
    assert subhanallah.find("naruto", getStr) == @[]    

discard """
  
  Translate soft-sub ke bahasa tujuan.
  Bisa make Gemini, atau Built-in (scrape).

  Support .ass, .vtt, .srt
  Tar dibenerin lagi ygy.

"""
import
  types

import
  strutils, sequtils

import
  ../translator/all

type
  LineContent = tuple[
    idx: int,
    text: string
  ]

  ChunkedLineContent = tuple[
    idxes: seq[int],
    translatedLines: seq[string],
    rawLines: seq[string]
  ]

proc merge(chunk: ChunkedLineContent; place: var seq[string]) =
  for (i, supami) in zip(chunk.idxes, zip(chunk.translatedLines, chunk.rawLines)):
    place[i] = place[i]
      .replace(supami[1], supami[0]) # Replace to translated line.
      .replace("&quot;", "\"") # Replace the sysmbol that already encoded by the translator.
      .replace("&lt;/b&gt;")
      .replace("&lt;b&gt;")

proc translateVTTV2*(subtitle: MediaSubtitle; header: MediaHttpHeader; targetLang: Languages; mode: WewboLogMode = mTui) {.gcsafe.} =
  let
    log = useWewboLogger("Subtitle Translator", mode = mode)  
    tll = getTranslator("google", targetLang, mode = mode)
    net = newHttpConnection("mgstatics.xyz", header, mode = mode)

  var
    idx: int # JANGAN LUPA DI RESET YA ANJENG.

  proc getSubtitle(): seq[string] =
    var
      resp: Response
      text: string

    resp = net.req(subtitle.url)

    if resp.status.contains("200"):
      text = resp.to_readable()

    result = text.splitLines()   

  proc parseASS(rawSub: seq[string]): seq[LineContent] =
    var parts: seq[string]
    for line in rawSub:
      if line.startsWith("Dialogue:"):
        parts = line.split(",", 9)
        if parts.len == 10:
          result.add((idx: idx, text: parts[9]))
      inc idx

    idx.reset()

  proc parseVTT(rawSub: seq[string]): seq[LineContent] =
    for line in rawSub:
      if not line.contains("-->") and line != "" and line != "WEBVTT":
        result.add( (idx: idx, text: line))
      inc idx

    idx.reset() 
  
  proc realTranslate(input: seq[LineContent]; chunkLen: int = 5): seq[ChunkedLineContent] =
    let
      rijal = input.distribute(chunkLen)
      seperator = " ||| "

    var
      hasil: seq[string]
      idxes: seq[int]

    for i, chunk in rijal:
      log.info "Translating Chunk " & $(i + 1)
      hasil.reset()
      idxes.reset()

      for r in chunk:
        hasil.add(r.text)
        idxes.add(r.idx)

      result.add (
        idxes: idxes,
        translatedLines: tll.translate(hasil.join seperator).split seperator,
        rawLines: hasil
      )  
  
  var
    hasil = getSubtitle()    
    filename = "wewbo-auto-sub"

  var
    sek: seq[LineContent]

  case subtitle.ext
  of sAss:
    sek = hasil.parseASS()
    filename &= ".ass"
  of sVtt:
    sek = hasil.parseVTT()
    filename &= ".vtt"
  of sUnkown:
    return

  for chunk in sek.realTranslate():
    chunk.merge(hasil)    

  filename.writeFile(hasil.join("\n"))
  subtitle.url = filename

when isMainModule:
  import
    ../extractor/all,
    ../player/all

  let
    player = getPlayer("mpv")

  let
    ex = getExtractor("hime", mode = "tui")
    an = ex.get ex.animes("uma musume")[0]
    ep = ex.get ex.episodes(an)[2]
    fm = ex.formats(ep)[0]
    subs = ex.subtitles fm
    meta = ex.get fm

  # echo subs.get[0].url

  # let
    # komi = translateVTTV2()

  let dea = subs.get[1]

  dea.translateVTTV2(meta.headers.get, laId)
  player.watch(meta, some dea)

  # writeFile("deket.vtt", subs.get[0].translateVTTV2(meta.headers.get, laSu))

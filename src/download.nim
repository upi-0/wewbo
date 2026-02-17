import
  os,
  extractor/[all, types],
  tui/[base, logger],
  tui/ask,
  media/[types, downloader],
  terminal/paramarg

from sequtils import zip
from strutils import split, parseInt, contains

proc setFormat(formatIndex: var int, values: seq[ExFormatData], spami: string = "") =
  let va = values.find(values.ask(title=spami))
  formatIndex = va

proc setSubtitle(subtitleIndex: var int, values: seq[MediaSubtitle], spami: string = "") =
  subtitleIndex = values.find(values.ask(title=spami))

proc download*(f: FullArgument) =
  proc normalizeIndex(ss: int; dd: int) : CBNormalizeIndex =
    proc normalizeIndexRezult(max: int) : HSlice[int, int]=
      var
        sz = ss
        dz = dd

      if dd == -1:
        dz = max      
      if ss == -1:
        sz = 1
      if dd == 0:
        dz = sz      
      if sz > max:
        raise newException(ValueError, "Invalid Index.")
      
      return sz - 1 .. dz - 1

    return normalizeIndexRezult

  proc getIndex(container: seq[string], target: int, def: int) : int =
    try:
      if container[target] == "":
        result = -1        
      else: 
        result = container[target].parseInt()
    except IndexDefect, ValueError:
      result = def

  let
    requestedIdx = f["episode"].getStr()

  var
    episodeIdx: seq[string]
    selectedEpisodeStart: int = -1
    selectedEpisodeEnd: int = -1

  if requestedIdx != "":
    episodeIdx = requestedIdx.split("-")
    selectedEpisodeStart = episodeIdx.getIndex(0, -1)
    selectedEpisodeEnd = episodeIdx.getIndex(1, 0)

  let
    fallback: CallbacksGetAllEpisodes = (
      episodeFormats: setFormat,
      episodeSubtitles: setSubtitle,
      normalizeIndex: normalizeIndex(selectedEpisodeStart, selectedEpisodeEnd)
    )

  let ffmpegDownloadOption: FfmpegDownloaderOption = (
    crf: f["crf"].getInt(),
    fps: f["fps"].getInt(),
    sub: not f["nsub"].getBool()
  )
  
  let
    log = newWewboLogger("Downloading")
    palla = getExtractor(f["source"].getStr)
    anime = palla.ask(f.nargs[0])
    tdr = f["outdir"].getStr()
    rijal = newFfmpegDownloader(outdir = if tdr != "": tdr else: anime.title, options = ffmpegDownloadOption)

  let
    animeUrl = palla.get(anime)
    episodes = palla.getAllEpisodeFormats(animeUrl, selectedEpisodeStart, selectedEpisodeEnd, fallback)
    outputCode = rijal.downloadAll(episodes.formats, episodes.titles)

  log.info("[INFO] Inspecting")

  for (title, code) in zip(episodes.titles, outputCode) :
    if code < 1:
      log.info("[INFO] Success downloading: " & title)
    else:
      log.warn("[WARN] Failed downloading: " & title)

  sleep(3_000)  
  log.close()

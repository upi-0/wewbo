import
  extractor/all,
  tui/logger,
  ui/ask,
  media/[types, downloader],
  terminal/paramarg

from stream import askAnime
from sequtils import zip

proc setFormat(formatIndex: var int, values: seq[ExFormatData], spami: string = "") =
  let va = values.find(values.ask(title=spami))
  formatIndex = va

proc setSubtitle(subtitleIndex: var int, values: seq[MediaSubtitle], spami: string = "") =
  subtitleIndex = values.find(values.ask(title=spami))

proc download*(f: FullArgument) =
  let
    log = newWewboLogger("Downloading")
    palla = getExtractor(f["source"].getStr)
    anime = palla.askAnime(f.nargs[0])
    tdr = f["outdir"].getStr
    rijal = newFfmpegDownloader(outdir = if tdr != "": tdr else: anime.title)

  let        
    animeUrl = palla.get(anime)
    episodes = palla.getAllEpisodeFormats(animeUrl, setFormat, setSubtitle)
    outputCode = rijal.downloadAll(episodes.formats, episodes.titles)

  for (title, code) in zip(episodes.titles, outputCode) :
    log.info("[INFO] Inspecting")

    if code < 1:
      log.info("[INFO] Success downloading: " & title)
    else:
      log.warn("[WARN] Failed downloading: " & title)

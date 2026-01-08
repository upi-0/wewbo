import
  extractor/all,
  tui/[logger, base],
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
    palla = getExtractor(f["source"].getStr)
    anime = palla.askAnime(f.nargs[0])
    tdr = f["outdir"].getStr
    log = newWewboLogger("Download")
    rijal = newFfmpegDownloader(
      outdir = if tdr != "": tdr else: anime.title
    )

  let        
    animeUrl = palla.get anime
    episodes = palla.episodes(animeUrl)

  var
    episodeTitle: seq[string]
    episodeFormat: seq[MediaFormatData]
    allFormat: seq[ExFormatData]
    episodeMed: MediaFormatData
    res: MediaResolution
    episodeUrl: string
    fInex: int = -1

  proc extractFormat(ept: EpisodeData) =
    episodeUrl = palla.get(ept)
    allFormat = palla.formats(episodeUrl)

    if fInex == -1 :
      fInex.setFormat(allFormat)
      res = allFormat[fInex].title.detectResolution()

    try:
      assert allFormat[fInex].title.detectResolution() == res
      log.info("[dl] auto select for " & spami)
      episodeMed = palla.get(allFormat[finex])

    except RangeDefect, IndexDefect, AssertionDefect:
      finex.setFormat(allFormat)
      episodeMed = palla.get(allFormat[finex])
      
    episodeFormat.add(episodeMed)

  for (title, code) in zip(episodes.titles, outputCode) :
    log.info("[INFO] Inspecting")

    if code < 1:
      log.info("[INFO] Success downloading: " & title)
    else:
      log.warn("[WARN] Failed downloading: " & title)

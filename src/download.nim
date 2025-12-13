import
  logger,
  extractor/all,
  ui/ask,
  media/[downloader, types]

from main import askAnime

proc setFormat(formatIndex: var int, values: seq[ExFormatData]) =
  let va = values.find(values.ask())
  formatIndex = va

proc download*(title: string, extratorName: string = "kura") =
  let
    palla = getExtractor(extratorName)
    anime = palla.askAnime(title)
    animeUrl = palla.get anime
    episodes = palla.episodes(animeUrl)
    rijal = newFfmpegDownloader(outdir = anime.title)
  
  var
    episodeTitle: seq[string]
    episodeFormat: seq[MediaFormatData]
    allFormat: seq[ExFormatData]
    episodeMed: MediaFormatData
    episodeUrl: string
    fInex: int = -1
    
  proc extractFormat(ept: EpisodeData) =
    episodeUrl = palla.get(ept)
    allFormat = palla.formats(episodeUrl)

    if fInex == -1 :
      fInex.setFormat(allFormat)

    try:
      episodeMed = palla.get(allFormat[finex])
    except RangeDefect, IndexDefect:
      finex.setFormat(allFormat)
      episodeMed = palla.get(allFormat[finex])
      
    episodeFormat.add(episodeMed)

  for ept in episodes :
    episodeTitle.add(ept.title)
    extractFormat(ept)

  log.info($rijal.downloadAll(episodeFormat, episodeTitle))

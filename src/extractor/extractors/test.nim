import
  ../base, q, xmltree,
  ../../tui/logger,
  strutils

type
  TestEX* {.final.} = ref object of BaseExtractor

proc newTest*(ex: var BaseExtractor) =
  ex = TestEX()
  ex.host = "localhost:5500"
  ex.name = "test"
  ex.supportCompessed = false

proc extract(ex: TestEx; path: string): seq[tuple[title, url: string]] =
  let el = ex.main_els(path, "div.file-container")

  for anchorFile in el[0].select("a"):
    result.add (
      title: anchorFile.innerText,
      url: anchorFile.attr("href").replace(" ", "%20")
    )

method animes*(ex: TestEX; title: string): seq[AnimeData] =
  for f in ex.extract("/"):
    result.add AnimeData(
      title: f.title,
      url: f.url
    )

method episodes*(ex: TestEX; url: string): seq[EpisodeData] =
  for f in ex.extract(url):
    result.add EpisodeData(
      title: f.title,
      url: f.url
    )

method formats(ex: TestEX; url: string): seq[ExFormatData] =
  for f in ex.extract(url):
    result.add ExFormatData(
      title: f.title,
      format_identifier: f.url
    )

method get(ex: TestEX; data: ExFormatData): MediaFormatData =
  result.video = "http://" & ex.host & data.format_identifier
  result.typeExt = extMp4

when isMainModule:
  var
    rijal: BaseExtractor
    daa: string
  
  newTest(rijal)
  init(rijal, logMode=mEcho)

  for an in rijal.episodes("Anime%202"):
     daa = an.url

  echo daa

  for fm in rijal.formats(daa):
    echo fm.format_identifier

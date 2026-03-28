import
  os, opt, sugar, sequtils, options,
  extractor/[all, types],
  tui/[base, logger, ask],
  media/[types, downloader],
  terminal/paramarg

proc download2*(f: FullArgument = nil) =
  let
    # (animeTitle, exName) = parseTitleAndSource(f.nargs[0], f["source"].getStr())
    (animeTitle, exName) = parseTitleAndSource("29", "taku")    
    extractor = getExtractor(exName)
    anime = extractor.ask(animeTitle)
    epds = extractor.episodes extractor.get anime
    formatResolution = extractor.formats extractor.get epds[0]
    logger = useWewboLogger("Downloader")

  var
    episodeTitleAndFormats: AllEpisodeFormats
    args = OptionArgs()
  
  proc setArgsDownloader =
    let epdsLen = epds.len
    args.putRange(1, epdsLen, "Episode Range Start", 1)
    args.putRange(1, epdsLen, "Episode Range End", epdsLen)
    args.putEnum(formatResolution, "Format Resolution")

    block ffmpegDownloaderOption:
      args.put(anime.title, "Output Directory")
      args.putBool("With Subtitle")
      args.putRange(10, 30, "FPS", 25)
      args.putRange(20, 30, "CRF", 28)

  proc extract =
    if args["Output Directory"].s.dirExists():
      raise newException(RangeDefect, "The output directory is already available. Try to change it.")

    var
      episodeTitles: seq[string]
      episodeFormats: seq[MediaFormatData]
      selectedSubtitleIndex = -1
      selectedFormatIndex = block:
        formatResolution
        .map(format => format.title)
        .find(args["Format Resolution"].s)
      selectedFormatResolution = args["Format Resolution"].s.detectResolution()  

    proc selectFormat(allFormat: seq[ExFormatData]): int {.inline.} =
      allFormat.find allFormat.ask("Reselect Format")

    proc selectSubtitle(subs: seq[MediaSubtitle]): int {.inline.} =
      subs.find subs.ask("Select Subtitle")

    proc format(ept: EpisodeData): MediaFormatData =
      let
        episodeUrl = extractor.get(ept)
        allFormat = extractor.formats(episodeUrl)
        ex = extractor

      try:
        assert block:
          allFormat[selectedFormatIndex].title.detectResolution() ==
          selectedFormatResolution
        result = ex.get allFormat[selectedFormatIndex]
      except Exception:        
        let tempSelectedFormatIndex = selectFormat allFormat
        result = ex.get allFormat[tempSelectedFormatIndex]

      if args["With Subtitle"].b: 
        let episodeSubtitles = ex.subtitles allFormat[selectedFormatIndex]

        if episodeSubtitles.isSome:
          let episodeSubs = episodeSubtitles.get

          if selectedSubtitleIndex == -1:
            selectedSubtitleIndex = selectSubtitle episodeSubs

          try:
            result.subtitle = some episodeSubs[selectedSubtitleIndex]
          except RangeDefect:
            let tempSelectedSubtitleIndex = selectSubtitle episodeSubs
            result.subtitle = some episodeSubs[tempSelectedSubtitleIndex]

        else:
          logger.text("[DL] Subtitle is not exist for this format. Skip", color(fgYellow))

    for ept in epds[args["Episode Range Start"].n - 1 .. args["Episode Range End"].n - 1]:
      logger.text("[DL] Extractiong format: " & ept.title, color(fgGreen))
      episodeTitles.add ept.title
      episodeFormats.add ept.format

    episodeTitleAndFormats = (episodeTitles, episodeFormats)

  proc tryExtract =
    try:
      args.ask()
      extract()
    except Exception:
      logger.error("[DL] " & getCurrentExceptionMsg())
      tryExtract()  

  proc downloadAll =
    let
      ffmpegDownloadOption: FfmpegDownloaderOption = (
        crf: args["CRF"].n,
        fps: args["FPS"].n,
        sub: args["With Subtitle"].b
      )
      downloader = newFfmpegDownloader(
        outdir = args["Output Directory"].s,
        options = ffmpegDownloadOption
      )
      outputCode = downloader.downloadAll(episodeTitleAndFormats.formats, episodeTitleAndFormats.titles)      

    logger.info("[DL] Inspecting")

    for (title, code) in zip(episodeTitleAndFormats.titles, outputCode):
      if code < 1:
        logger.text("[DL] Success: " & title, color(fgGreen))
      else:
        logger.warn("[DL] Failed: " & title)  

  setArgsDownloader()
  tryExtract()
  downloadAll()

  logger.error("Task Completed")    
  illwillDeinit()

when isMainModule:
  download2()

import
  os, opt, sequtils, strutils, sets, options, illwill,
  extractor/[all, types],
  tui/[logger, ask],
  media/[types, downloader, format],
  terminal/paramarg

const
  SubtitleModeChoices = ["soft", "hard", "external", "none"]
  ContainerChoices = ["auto", "mp4", "mkv"]

proc parseEpisodeSpec*(spec: string; maxEpisode: int): seq[int] {.gcsafe.} =
  ## Parse an episode specification like "all", "5", "1-12", "3-", "-5", or "1,3,5-8"
  ## into a deduplicated, order-preserving sequence of 1-based episode numbers.
  if maxEpisode < 1:
    raise newException(ValueError, "No episodes available.")

  let trimmed = spec.strip().toLowerAscii()
  if trimmed.len == 0 or trimmed == "all":
    for i in 1 .. maxEpisode:
      result.add(i)
    return

  var seen = initHashSet[int]()
  for rawPart in trimmed.split(','):
    let part = rawPart.strip()
    if part.len == 0:
      continue

    if part.contains('-'):
      let bounds = part.split('-', 1)
      let startStr = bounds[0].strip()
      let endStr = bounds[1].strip()

      var startEp, endEp: int
      try:
        startEp = if startStr.len == 0: 1 else: parseInt(startStr)
        endEp = if endStr.len == 0: maxEpisode else: parseInt(endStr)
      except ValueError:
        raise newException(ValueError, "Invalid episode range: '" & part & "'")

      if startEp < 1 or endEp < 1 or startEp > maxEpisode or endEp > maxEpisode:
        raise newException(ValueError, "Episode range '" & part & "' is out of bounds (1.." & $maxEpisode & ").")
      if startEp > endEp:
        raise newException(ValueError, "Invalid episode range '" & part & "': start (" & $startEp & ") > end (" & $endEp & ").")

      for ep in startEp .. endEp:
        if ep notin seen:
          seen.incl(ep)
          result.add(ep)
    else:
      var ep: int
      try:
        ep = parseInt(part)
      except ValueError:
        raise newException(ValueError, "Invalid episode number: '" & part & "'")

      if ep < 1 or ep > maxEpisode:
        raise newException(ValueError, "Episode " & $ep & " is out of bounds (1.." & $maxEpisode & ").")
      if ep notin seen:
        seen.incl(ep)
        result.add(ep)

  if result.len == 0:
    raise newException(ValueError, "Episode spec '" & spec & "' matched no episodes.")

proc matchSubtitle*(subs: seq[MediaSubtitle]; preferredLabel: string): Option[MediaSubtitle] {.gcsafe.} =
  ## Match a subtitle by exact case-insensitive label first, then substring match on title/lang.
  let pref = preferredLabel.strip().toLowerAscii()
  if subs.len == 0 or pref.len == 0:
    return none(MediaSubtitle)

  for sub in subs:
    if sub.title.strip().toLowerAscii() == pref or sub.lang.strip().toLowerAscii() == pref:
      return some(sub)

  for sub in subs:
    if sub.title.toLowerAscii().contains(pref) or sub.lang.toLowerAscii().contains(pref):
      return some(sub)

  return none(MediaSubtitle)

proc existingEpisodePath(outdir, outputName: string; container: ContainerFormat): Option[string] {.gcsafe.} =
  let safeName = sanitizeFilename(outputName)
  let candidates =
    case container
    of cfMkv: @[outdir / (safeName & ".mkv")]
    of cfMp4: @[outdir / (safeName & ".mp4")]
    of cfAuto: @[outdir / (safeName & ".mkv"), outdir / (safeName & ".mp4")]

  for path in candidates:
    if fileExists(path) and getFileSize(path) > 0:
      return some(path)
  return none(string)

proc download2*(f: FullArgument = nil) {.gcsafe.} =
  if f.isNil or f.nargs.len < 1:
    raise newException(ValueError, "Missing anime title. Try: `wewbo ani-dl 'Anime Title'`")

  let
    (animeTitle, exName) = parseTitleAndSource(f.nargs[0], f["source"].getStr())
    episodeSpecArg = f["episodes"].getStr().strip()
    outdirArg = f["outdir"].getStr().strip()
    qualityArg = f["quality"].getStr().strip()
    subModeDefault = parseSubtitleMode(f["sub_mode"].getStr())
    subLangArg = f["sub_lang"].getStr().strip()
    containerDefault = parseContainerFormat(f["container"].getStr())
    reencodeArg = f["reencode"].getBool()
    crfArg = clamp(f["crf"].getInt(), 0, 51)
    fpsArg = max(0, f["fps"].getInt())
    workersArg = clamp(f["workers"].getInt(), 1, 8)
    retriesArg = max(0, f["retries"].getInt())
    overwriteArg = f["overwrite"].getBool()
    ffmpegPathArg = f["ffmpeg_path"].getStr().strip()
    yesFlag = f["yes"].getBool()

  let
    extractor = getExtractor(exName)
    anime = extractor.ask(animeTitle)
    epds = extractor.episodes(extractor.get(anime))

  if epds.len == 0:
    raise newException(EpisodeNotFoundError, "No episodes found for: " & anime.title)

  let
    epdsLen = epds.len
    hasExplicitEpList = episodeSpecArg.len > 0 and episodeSpecArg.contains(',')
    initialEpisodes =
      if episodeSpecArg.len > 0:
        parseEpisodeSpec(episodeSpecArg, epdsLen)
      else:
        toSeq(1 .. epdsLen)

    sampleEpisode = epds[initialEpisodes[0] - 1]
    formatResolution = extractor.formats(extractor.get(sampleEpisode))
    logger = useWewboLogger("Ani-DL")

  if formatResolution.len == 0:
    raise newException(ValueError, "No downloadable formats found for: " & sampleEpisode.title)

  var defaultFormatIdx = 0
  if qualityArg.len > 0:
    let matched = matchQualityPreference(formatResolution, qualityArg)
    if matched.isSome:
      let foundIdx = formatResolution.find(matched.get)
      if foundIdx >= 0:
        defaultFormatIdx = foundIdx

  let
    defaultOutdir = if outdirArg.len > 0: outdirArg else: sanitizeFilename(anime.title)
    defaultSubIdx = SubtitleModeChoices.find($subModeDefault)
    defaultContainerIdx = ContainerChoices.find($containerDefault)

  var args = OptionArgs()

  if not hasExplicitEpList:
    args.putRange(1, epdsLen, "Episode Range Start", initialEpisodes[0])
    args.putRange(1, epdsLen, "Episode Range End", initialEpisodes[^1])

  args.putEnum(formatResolution, "Format Resolution", defaultIdx = defaultFormatIdx)
  args.put(defaultOutdir, "Output Directory")
  args.putEnum(SubtitleModeChoices, "Subtitle Mode", defaultIdx = max(0, defaultSubIdx))
  args.putEnum(ContainerChoices, "Container", defaultIdx = max(0, defaultContainerIdx))
  args.putBool("Keep Format", default = not reencodeArg)
  args.putRange(1, 8, "Workers", default = workersArg)
  args.putBool("Overwrite Existing", default = overwriteArg)

  var
    selectedEpisodes: seq[int]
    selectedFormatTitle: string
    outdir: string
    subMode: SubtitleMode
    container: ContainerFormat
    keepFormat: bool
    workerCount: int
    overwrite: bool

  # Iterative validation loop (no recursion, no duplicate inputs)
  while true:
    if yesFlag:
      args.applyDefaults()
    else:
      args.ask("Ani-DL Options")

    try:
      if hasExplicitEpList:
        selectedEpisodes = initialEpisodes
      else:
        let
          startEp = args["Episode Range Start"].n
          endEp = args["Episode Range End"].n
        if startEp > endEp:
          raise newException(ValueError, "Episode Range Start (" & $startEp & ") cannot be greater than End (" & $endEp & ").")
        selectedEpisodes = toSeq(startEp .. endEp)

      outdir = args["Output Directory"].s.strip()
      if outdir.len == 0:
        raise newException(ValueError, "Output Directory cannot be empty.")

      selectedFormatTitle = args["Format Resolution"].s
      subMode = parseSubtitleMode(args["Subtitle Mode"].s)
      container = parseContainerFormat(args["Container"].s)
      keepFormat = args["Keep Format"].b
      workerCount = clamp(args["Workers"].n, 1, 8)
      overwrite = args["Overwrite Existing"].b
      break
    except CatchableError as e:
      if yesFlag:
        raise
      logger.error("[DL] " & e.msg)

  let ffmpegOptions = FfmpegDownloaderOption(
    crf: crfArg,
    fps: fpsArg,
    subtitleMode: subMode,
    keepFormat: keepFormat,
    container: container,
    overwrite: overwrite,
    retries: retriesArg,
    ffmpegPath: if ffmpegPathArg.len > 0: ffmpegPathArg else: "ffmpeg"
  )

  var
    inputs: seq[FfmpegMediaInput] = @[]
    preSkipped: seq[DownloadResult] = @[]
    extractFailed: seq[DownloadResult] = @[]
    selectedSubtitleLabel = subLangArg

  logger.text("[DL] Preparing " & $selectedEpisodes.len & " episode(s) -> " & outdir, color(fgCyan))

  for epNum in selectedEpisodes:
    let
      ept = epds[epNum - 1]
      outName = formatEpisodeOutputName(ept.title, epNum, epdsLen)

    if not overwrite:
      let existing = existingEpisodePath(outdir, outName, container)
      if existing.isSome:
        logger.text("[DL] Skipping existing: " & extractFilename(existing.get), color(fgCyan))
        preSkipped.add(DownloadResult(
          outputName: outName,
          outputPath: existing.get,
          status: dsSkipped,
          exitCode: 0,
          attempts: 0
        ))
        continue

    logger.text("[DL] Extracting: " & ept.title, color(fgGreen))
    try:
      let
        episodeUrl = extractor.get(ept)
        allFormat = extractor.formats(episodeUrl)
        exmedia = findBestMatch(allFormat, selectedFormatTitle, allowInteractive = not yesFlag)
        fmtIdentity = detectFormat(exmedia.title)

      var media = extractor.get(exmedia)
      logger.text("[DL] Selected format: " & exmedia.title, color(fgGreen))

      if subMode != smNone:
        let episodeSubtitles = extractor.subtitles(exmedia)
        if episodeSubtitles.isSome and episodeSubtitles.get.len > 0:
          let subs = episodeSubtitles.get
          var chosen = matchSubtitle(subs, selectedSubtitleLabel)

          if chosen.isNone:
            if yesFlag:
              chosen = some(subs[0])
              selectedSubtitleLabel = subs[0].title
            else:
              let picked = subs.ask("Select Subtitle")
              chosen = some(picked)
              selectedSubtitleLabel = picked.title

          media.subtitle = chosen
        else:
          logger.warn("[DL] No subtitles available for: " & ept.title)

      inputs.add((media: media, outputName: outName, formatIdentity: fmtIdentity))
    except CatchableError as e:
      logger.warn("[DL] Extraction failed for " & ept.title & ": " & e.msg)
      extractFailed.add(DownloadResult(
        outputName: outName,
        outputPath: outdir / sanitizeFilename(outName),
        status: dsFailed,
        exitCode: 1,
        attempts: 1,
        errorMsg: "Extraction error: " & e.msg
      ))

  let dlResults =
    if inputs.len > 0:
      downloadAll(outdir, ffmpegOptions, inputs, workers = workerCount, log = logger)
    else:
      @[]

  var
    succeededCount = 0
    skippedCount = preSkipped.len
    failedResults = extractFailed

  for r in dlResults:
    case r.status
    of dsSuccess: inc succeededCount
    of dsSkipped: inc skippedCount
    of dsFailed: failedResults.add(r)

  logger.info("[DL] ----------------------------------------")
  logger.text(
    "[DL] Summary: $# succeeded | $# skipped | $# failed" % [
      $succeededCount, $skippedCount, $failedResults.len
    ],
    if failedResults.len == 0: color(fgGreen) else: color(fgYellow)
  )
  logger.info("[DL] Output Directory: " & absolutePath(outdir))

  for fail in failedResults:
    logger.warn("[DL] Failed: $# -> $#" % [fail.outputName, fail.errorMsg])

  if not yesFlag:
    logger.pause("Task Completed", if failedResults.len == 0: color(fgGreen) else: color(fgYellow))

  illwillDeinit()
  showCursor()
  logger.exportLog("dl.log")

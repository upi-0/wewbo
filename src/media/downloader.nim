import
  os,
  osproc,
  net,
  oids,
  locks,
  tables,
  options,
  strutils,
  math,
  illwill,
  malebolgia

import
  ../process,
  ../media/[format, types],
  ../tui/logger

type
  SubtitleMode* = enum
    smSoft = "soft"
    smHard = "hard"
    smExternal = "external"
    smNone = "none"

  ContainerFormat* = enum
    cfAuto = "auto"
    cfMp4 = "mp4"
    cfMkv = "mkv"

  FfmpegDownloaderOption* = object
    crf*: int = 23
    fps*: int = 0
    preset*: string = "veryfast"
    subtitleMode*: SubtitleMode = smSoft
    keepFormat*: bool = true
    container*: ContainerFormat = cfAuto
    overwrite*: bool = false
    retries*: int = 2
    ffmpegPath*: string = "ffmpeg"

  FfmpegMediaInput* = tuple[
    media: MediaFormatData,
    outputName: string,
    formatIdentity: FormatIdentity
  ]

  DownloadStatus* = enum
    dsSuccess = "Success"
    dsSkipped = "Skipped"
    dsFailed = "Failed"

  DownloadResult* = object
    outputName*: string
    outputPath*: string
    status*: DownloadStatus
    exitCode*: int
    attempts*: int
    errorMsg*: string

  FfmpegDownloader* = ref object of CliApplication
    outdir*: string
    options*: FfmpegDownloaderOption
    currentDurationSec*: float = 0.0
    currentLabel*: string = ""
    lastErrorLine*: string = ""

type
  HlsDemuxerFlags = object
    allowedExtensions: bool
    allowedSegmentExtensions: bool
    extensionPicky: bool

const
  FfmpegProtocolWhitelist = "file,http,https,tcp,tls,crypto,data,httpproxy"
  FfmpegProxyHost = "127.0.0.1"
  FfmpegProxyPort = Port(56767)
  FfmpegHttpProxy = "http://localhost:56767"

var
  hlsProbeLock: Lock
  hlsProbeCache = initTable[string, HlsDemuxerFlags]()

initLock(hlsProbeLock)

proc isLocalProxyAvailable*(): bool {.gcsafe.} =
  var sock = newSocket()
  try:
    sock.connect(FfmpegProxyHost, FfmpegProxyPort, timeout = 150)
    result = true
  except CatchableError:
    result = false
  finally:
    try: sock.close()
    except CatchableError: discard

proc probeHlsDemuxerFlags(ffmpegExe: string): HlsDemuxerFlags {.gcsafe.} =
  let key = if ffmpegExe.len > 0: ffmpegExe else: "ffmpeg"
  withLock(hlsProbeLock):
    {.cast(gcsafe).}:
      if key in hlsProbeCache:
        return hlsProbeCache[key]

  var detected = HlsDemuxerFlags(allowedExtensions: true)
  try:
    let (outp, code) = execCmdEx(quoteShell(key) & " -hide_banner -h demuxer=hls")
    if code == 0:
      detected.allowedExtensions = outp.contains("-allowed_extensions")
      detected.allowedSegmentExtensions = outp.contains("-allowed_segment_extensions")
      detected.extensionPicky = outp.contains("-extension_picky")
  except CatchableError:
    discard

  withLock(hlsProbeLock):
    {.cast(gcsafe).}:
      hlsProbeCache[key] = detected
  return detected

proc parseSubtitleMode*(s: string): SubtitleMode {.gcsafe.} =
  case s.strip().toLowerAscii()
  of "soft", "mux": smSoft
  of "hard", "burn": smHard
  of "external", "ext", "sidecar": smExternal
  of "none", "off", "false": smNone
  else:
    raise newException(ValueError, "Invalid subtitle mode: '" & s & "'. Expected one of: soft, hard, external, none")

proc parseContainerFormat*(s: string): ContainerFormat {.gcsafe.} =
  case s.strip().toLowerAscii()
  of "auto", "": cfAuto
  of "mp4": cfMp4
  of "mkv": cfMkv
  else:
    raise newException(ValueError, "Invalid container format: '" & s & "'. Expected one of: auto, mp4, mkv")

proc sanitizeFilename*(s: string): string {.gcsafe.} =
  const forbidden = {'/', '\\', ':', '*', '?', '"', '<', '>', '|', '[', ']', ','}
  var cleaned = newStringOfCap(s.len)
  var lastWasDash = false

  for ch in s.strip():
    if ord(ch) < 32:
      continue
    if ch in forbidden:
      continue
    if ch == ' ' or ch == '\t':
      if not lastWasDash and cleaned.len > 0:
        cleaned.add('-')
        lastWasDash = true
    elif ch == '-':
      if not lastWasDash and cleaned.len > 0:
        cleaned.add('-')
        lastWasDash = true
    else:
      cleaned.add(ch)
      lastWasDash = false

  result = cleaned.strip(chars = {'-', '.', ' '})
  while result.contains(".."):
    result = result.replace("..", "")
  if result.len == 0:
    result = "episode"

proc formatEpisodeOutputName*(title: string; epIndex, totalEpisodes: int): string {.gcsafe.} =
  ## Format episode name with zero-padded numbering for clean lexicographical sorting.
  let width = max(2, len($max(1, totalEpisodes)))
  let trimmed = title.strip()
  let lower = trimmed.toLowerAscii()

  if lower.startsWith("episode "):
    let rest = trimmed[8 .. ^1].strip()
    var allDigits = rest.len > 0
    for ch in rest:
      if ch notin Digits:
        allDigits = false
        break
    if allDigits:
      return "Episode-" & rest.align(width, '0')

  if trimmed.len > 0:
    var allDigits = true
    for ch in trimmed:
      if ch notin Digits:
        allDigits = false
        break
    if allDigits:
      return "Episode-" & trimmed.align(width, '0')
    return sanitizeFilename(trimmed)

  return "Episode-" & ($epIndex).align(width, '0')

proc resolveTargetExt*(media: MediaFormatData; options: FfmpegDownloaderOption): string {.gcsafe.} =
  case options.container
  of cfMkv: return "mkv"
  of cfMp4: return "mp4"
  of cfAuto:
    if media.subtitle.isSome and options.subtitleMode == smSoft:
      return "mkv"
    case media.typeExt
    of extMkv: return "mkv"
    of extMp4, extM3u8, extNone: return "mp4"

proc plannedOutputPath*(outdir, outputName: string; media: MediaFormatData; options: FfmpegDownloaderOption): string {.gcsafe.} =
  let
    safeName = sanitizeFilename(outputName)
    ext = resolveTargetExt(media, options)
  outdir / (safeName & "." & ext)

proc buildHeaderString*(headers: Option[MediaHttpHeader]): string {.gcsafe.} =
  if headers.isNone:
    return ""
  let h = headers.get
  var lines: seq[string] = @[]
  if h.userAgent.len > 0:
    lines.add("User-Agent: " & h.userAgent)
  if h.referer.len > 0:
    lines.add("Referer: " & h.referer)
  if h.cookie.len > 0:
    lines.add("Cookie: " & h.cookie)
  if h.origin.len > 0:
    lines.add("Origin: " & h.origin)
  if lines.len == 0:
    return ""
  lines.join("\r\n") & "\r\n"

proc isHttpUrl(url: string): bool {.inline, gcsafe.} =
  let lower = url.toLowerAscii()
  lower.startsWith("http://") or lower.startsWith("https://")

proc escapeFfmpegFilterPath*(path: string): string {.gcsafe.} =
  ## Escape path for FFmpeg filtergraph `ass=<path>` syntax.
  result = path
    .replace("\\", "\\\\")
    .replace(":", "\\:")
    .replace("'", "\\'")
    .replace("[", "\\[")
    .replace("]", "\\]")

proc parseFfmpegTimestamp*(ts: string): float {.gcsafe.} =
  ## Parse `HH:MM:SS.xx` into seconds. Returns -1.0 if invalid.
  let parts = ts.strip().split(':')
  if parts.len != 3:
    return -1.0
  try:
    let
      h = parseFloat(parts[0])
      m = parseFloat(parts[1])
      s = parseFloat(parts[2])
    if h < 0 or m < 0 or s < 0:
      return -1.0
    return h * 3600.0 + m * 60.0 + s
  except ValueError:
    return -1.0

proc parseFfmpegDuration*(line: string): float {.gcsafe.} =
  let idx = line.find("Duration:")
  if idx < 0:
    return -1.0
  let rest = line[idx + 9 .. ^1].strip()
  let comma = rest.find(',')
  let ts = if comma > 0: rest[0 ..< comma] else: rest
  parseFfmpegTimestamp(ts)

proc parseFfmpegTime*(line: string): float {.gcsafe.} =
  let idx = line.find("time=")
  if idx < 0:
    return -1.0
  let rest = line[idx + 5 .. ^1]
  let sp = rest.find(' ')
  let ts = if sp > 0: rest[0 ..< sp] else: rest
  parseFfmpegTimestamp(ts)

proc parseFfmpegSpeed*(line: string): string {.gcsafe.} =
  let idx = line.find("speed=")
  if idx < 0:
    return ""
  let rest = line[idx + 6 .. ^1].strip()
  let sp = rest.find(' ')
  if sp > 0: rest[0 ..< sp].strip() else: rest

proc formatDurationShort*(secs: float): string {.gcsafe.} =
  if secs < 0:
    return "00:00"
  let total = int(secs)
  let h = total div 3600
  let m = (total mod 3600) div 60
  let s = total mod 60
  if h > 0:
    "$#:$#:$#" % [$h, ($m).align(2, '0'), ($s).align(2, '0')]
  else:
    "$#:$#" % [($m).align(2, '0'), ($s).align(2, '0')]

proc renderProgressBar*(label: string; currentSec, totalSec: float; speed: string): string {.gcsafe.} =
  const barWidth = 16
  var parts: seq[string] = @[]
  if label.len > 0:
    parts.add(label)

  if totalSec > 0.0 and currentSec >= 0.0:
    let pct = clamp(currentSec / totalSec, 0.0, 1.0)
    let filled = int(round(pct * float(barWidth)))
    let bar = "[" & "#".repeat(filled) & "-".repeat(barWidth - filled) & "]"
    parts.add("$# $#%" % [bar, $(int(round(pct * 100.0)))])
    parts.add("$#/$#" % [formatDurationShort(currentSec), formatDurationShort(totalSec)])
  elif currentSec >= 0.0:
    parts.add("time=" & formatDurationShort(currentSec))

  if speed.len > 0:
    parts.add(speed)

  parts.join(" | ")

proc newFfmpegDownloader*(
  outdir: string;
  options: FfmpegDownloaderOption = FfmpegDownloaderOption();
  logMode: WewboLogMode = mTui
): FfmpegDownloader {.gcsafe.} =
  let exeName = if options.ffmpegPath.len > 0: options.ffmpegPath else: "ffmpeg"
  result = FfmpegDownloader(
    name: exeName,
    outdir: outdir,
    options: options,
    logMode: logMode
  ).setUp()

method failureHandler*(ffmpeg: FfmpegDownloader, context: CliError) {.gcsafe.} =
  raise newException(ValueError, "ffmpeg ('" & ffmpeg.name & "') is not detected on your system.")

method specialLine*(cli: FfmpegDownloader; text: string): bool {.gcsafe.} =
  text.contains("time=")

method formatSpecialLine*(cli: FfmpegDownloader; text: string): string {.gcsafe.} =
  let cur = parseFfmpegTime(text)
  let spd = parseFfmpegSpeed(text)
  if cur >= 0.0:
    return renderProgressBar(cli.currentLabel, cur, cli.currentDurationSec, spd)
  text.strip()

proc isFfmpegErrorLine(line: string): bool {.gcsafe.} =
  let lower = line.toLowerAscii()
  lower.contains("error") or lower.contains("invalid") or
    lower.contains("failed") or lower.contains("not on whitelist") or
    lower.contains("unrecognized")

proc addHttpInputArgs(ffmpeg: FfmpegDownloader; url: string; headers: Option[MediaHttpHeader]; isHls: bool = false) =
  if not isHttpUrl(url):
    return
  ffmpeg.addArg "-protocol_whitelist"
  ffmpeg.addArg FfmpegProtocolWhitelist
  if isLocalProxyAvailable():
    ffmpeg.addArg "-http_proxy"
    ffmpeg.addArg FfmpegHttpProxy
  let hdrStr = buildHeaderString(headers)
  if hdrStr.len > 0:
    ffmpeg.addArg "-headers"
    ffmpeg.addArg hdrStr
  let hlsInput = isHls or url.toLowerAscii().contains(".m3u8")
  if hlsInput:
    # Some anime CDNs disguise HLS playlists/segments with image extensions (e.g. .jpg/.jpeg)
    let exe = if ffmpeg.path.len > 0: ffmpeg.path else: ffmpeg.name
    let hlsFlags = probeHlsDemuxerFlags(exe)
    if hlsFlags.allowedExtensions:
      ffmpeg.addArg "-allowed_extensions"
      ffmpeg.addArg "ALL"
    if hlsFlags.allowedSegmentExtensions:
      ffmpeg.addArg "-allowed_segment_extensions"
      ffmpeg.addArg "ALL"
    if hlsFlags.extensionPicky:
      ffmpeg.addArg "-extension_picky"
      ffmpeg.addArg "0"
  else:
    ffmpeg.addArg "-reconnect"
    ffmpeg.addArg "1"
    ffmpeg.addArg "-reconnect_streamed"
    ffmpeg.addArg "1"
    ffmpeg.addArg "-reconnect_delay_max"
    ffmpeg.addArg "5"

proc addVideoEncodeArgs(ffmpeg: FfmpegDownloader) =
  ffmpeg.addArg "-c:v"
  ffmpeg.addArg "libx264"
  ffmpeg.addArg "-crf"
  ffmpeg.addArg $clamp(ffmpeg.options.crf, 0, 51)
  if ffmpeg.options.preset.len > 0:
    ffmpeg.addArg "-preset"
    ffmpeg.addArg ffmpeg.options.preset
  if ffmpeg.options.fps > 0:
    ffmpeg.addArg "-r"
    ffmpeg.addArg $ffmpeg.options.fps
  ffmpeg.addArg "-c:a"
  ffmpeg.addArg "copy"

proc downloadSubtitleFile(
  ffmpeg: FfmpegDownloader;
  sub: MediaSubtitle;
  headers: Option[MediaHttpHeader];
  destPath: string;
  convertToAss: bool
): int =
  ffmpeg.lastErrorLine = ""
  ffmpeg.args = @[]
  ffmpeg.addArg "-y"
  ffmpeg.addArg "-hide_banner"
  ffmpeg.addArg "-nostdin"
  ffmpeg.addHttpInputArgs(sub.url, headers)
  ffmpeg.addArg "-i"
  ffmpeg.addArg sub.url
  if convertToAss:
    ffmpeg.addArg "-c:s"
    ffmpeg.addArg "ass"
  ffmpeg.addArg destPath
  let lineHook: LineCallbackProc = proc(line: string) {.gcsafe.} =
    if isFfmpegErrorLine(line):
      ffmpeg.lastErrorLine = line.strip()
  ffmpeg.execute("Downloading Subtitle...", onLine = lineHook)

proc resolveSidecarExt(sub: MediaSubtitle): string {.gcsafe.} =
  case sub.ext
  of sAss: return "ass"
  of sVtt: return "vtt"
  of sUnkown:
    let lower = sub.url.toLowerAscii()
    if lower.contains(".vtt"): return "vtt"
    if lower.contains(".srt"): return "srt"
    return "ass"

proc downloadOnce(
  ffmpeg: FfmpegDownloader;
  input: MediaFormatData;
  outputName: string;
  finalPath: string;
  targetExt: string;
  label: string
): tuple[exitCode: int, errorMsg: string] =
  let
    safeName = sanitizeFilename(outputName)
    partPath = ffmpeg.outdir / (safeName & ".part." & targetExt)

  if not dirExists(ffmpeg.outdir):
    createDir(ffmpeg.outdir)

  var tempSubFile = ""
  defer:
    if tempSubFile.len > 0 and fileExists(tempSubFile):
      try: removeFile(tempSubFile)
      except OSError: discard

  let hasSub = input.subtitle.isSome and ffmpeg.options.subtitleMode != smNone

  if hasSub:
    let sub = input.subtitle.get
    case ffmpeg.options.subtitleMode
    of smSoft, smHard:
      tempSubFile = getTempDir() / ("wewbo_sub_" & $genOid() & ".ass")
      let subCode = ffmpeg.downloadSubtitleFile(sub, input.headers, tempSubFile, convertToAss = true)
      if subCode != 0 or not fileExists(tempSubFile) or getFileSize(tempSubFile) == 0:
        let detail = if ffmpeg.lastErrorLine.len > 0: " (" & ffmpeg.lastErrorLine & ")" else: ""
        return (exitCode: if subCode != 0: subCode else: 1, errorMsg: "Failed to download/convert subtitle: " & sub.url & detail)
    of smExternal:
      let subExt = resolveSidecarExt(sub)
      let sidecarPath = ffmpeg.outdir / (safeName & "." & subExt)
      let subCode = ffmpeg.downloadSubtitleFile(sub, input.headers, sidecarPath, convertToAss = false)
      if subCode != 0 or not fileExists(sidecarPath) or getFileSize(sidecarPath) == 0:
        let detail = if ffmpeg.lastErrorLine.len > 0: " (" & ffmpeg.lastErrorLine & ")" else: ""
        return (exitCode: if subCode != 0: subCode else: 1, errorMsg: "Failed to download external subtitle: " & sub.url & detail)
    of smNone:
      discard

  # Build main FFmpeg command
  ffmpeg.args = @[]
  ffmpeg.currentDurationSec = 0.0
  ffmpeg.currentLabel = label
  ffmpeg.lastErrorLine = ""

  ffmpeg.addArg "-y"
  ffmpeg.addArg "-hide_banner"
  ffmpeg.addArg "-nostdin"
  ffmpeg.addHttpInputArgs(input.video, input.headers, isHls = (input.typeExt == extM3u8))
  ffmpeg.addArg "-i"
  ffmpeg.addArg input.video

  if hasSub and ffmpeg.options.subtitleMode == smSoft:
    ffmpeg.addArg "-i"
    ffmpeg.addArg tempSubFile
    ffmpeg.addArg "-map"
    ffmpeg.addArg "0:v"
    ffmpeg.addArg "-map"
    ffmpeg.addArg "0:a?"
    ffmpeg.addArg "-map"
    ffmpeg.addArg "1:0"

    if ffmpeg.options.keepFormat:
      ffmpeg.addArg "-c:v"
      ffmpeg.addArg "copy"
      ffmpeg.addArg "-c:a"
      ffmpeg.addArg "copy"
    else:
      ffmpeg.addVideoEncodeArgs()

    ffmpeg.addArg "-c:s"
    if targetExt == "mkv":
      ffmpeg.addArg "ass"
    else:
      ffmpeg.addArg "mov_text"

    let subTitle = input.subtitle.get.title.strip()
    if subTitle.len > 0:
      ffmpeg.addArg "-metadata:s:s:0"
      ffmpeg.addArg "title=" & subTitle

  elif hasSub and ffmpeg.options.subtitleMode == smHard:
    # Burning subtitles requires video re-encoding; never combine -vf with -c copy
    ffmpeg.addArg "-vf"
    ffmpeg.addArg "ass=" & escapeFfmpegFilterPath(tempSubFile)
    ffmpeg.addVideoEncodeArgs()

  else:
    if ffmpeg.options.keepFormat:
      ffmpeg.addArg "-c"
      ffmpeg.addArg "copy"
    else:
      ffmpeg.addVideoEncodeArgs()

  ffmpeg.addArg partPath

  let lineHook: LineCallbackProc = proc(line: string) {.gcsafe.} =
    if ffmpeg.currentDurationSec <= 0.0:
      let dur = parseFfmpegDuration(line)
      if dur > 0.0:
        ffmpeg.currentDurationSec = dur
    if isFfmpegErrorLine(line):
      ffmpeg.lastErrorLine = line.strip()

  let code = ffmpeg.execute("Downloading " & outputName, onLine = lineHook)

  if code == 0 and fileExists(partPath) and getFileSize(partPath) > 0:
    if fileExists(finalPath):
      removeFile(finalPath)
    moveFile(partPath, finalPath)
    return (exitCode: 0, errorMsg: "")
  else:
    if fileExists(partPath):
      try: removeFile(partPath)
      except OSError: discard
    let errMsg =
      if ffmpeg.lastErrorLine.len > 0: ffmpeg.lastErrorLine
      elif code != 0: "ffmpeg exited with code " & $code
      else: "ffmpeg produced an empty output file"
    return (exitCode: if code != 0: code else: 1, errorMsg: errMsg)

proc downloadEpisode*(
  ffmpeg: FfmpegDownloader;
  input: MediaFormatData;
  outputName: string;
  label: string = ""
): DownloadResult {.gcsafe.} =
  let
    targetExt = resolveTargetExt(input, ffmpeg.options)
    finalPath = plannedOutputPath(ffmpeg.outdir, outputName, input, ffmpeg.options)
    displayLabel = if label.len > 0: label else: extractFilename(finalPath)

  result.outputName = outputName
  result.outputPath = finalPath

  if not ffmpeg.options.overwrite and fileExists(finalPath) and getFileSize(finalPath) > 0:
    result.status = dsSkipped
    result.exitCode = 0
    result.attempts = 0
    return result

  let maxAttempts = max(1, 1 + ffmpeg.options.retries)
  for attempt in 1 .. maxAttempts:
    result.attempts = attempt
    let (code, errMsg) = ffmpeg.downloadOnce(input, outputName, finalPath, targetExt, displayLabel)
    if code == 0:
      result.status = dsSuccess
      result.exitCode = 0
      result.errorMsg = ""
      return result

    result.exitCode = code
    result.errorMsg = errMsg
    if attempt < maxAttempts:
      if not ffmpeg.log.isNil:
        ffmpeg.log.warn("[DL] Retry $#/$# for $#: $#" % [$attempt, $(maxAttempts - 1), outputName, errMsg])
      sleep(2_000)

  result.status = dsFailed

proc download*(ffmpeg: FfmpegDownloader, input: MediaFormatData, output: string, targetExt: string = ""): int {.gcsafe.} =
  ## Convenience single-file download returning exit code (0 on success/skip).
  var opts = ffmpeg.options
  if targetExt == "mkv":
    opts.container = cfMkv
  elif targetExt == "mp4":
    opts.container = cfMp4
  let prevOpts = ffmpeg.options
  ffmpeg.options = opts
  defer: ffmpeg.options = prevOpts
  let res = ffmpeg.downloadEpisode(input, output)
  res.exitCode

type
  WorkerJob = object
    video: string
    typeExt: MediaExt
    hasHeaders: bool
    headers: MediaHttpHeader
    hasSub: bool
    subUrl: string
    subTitle: string
    subLang: string
    subExt: MediaSubtitleExt
    outputName: string

  WorkerSharedState = object
    lock: Lock
    nextIdx: int
    total: int
    outdir: string
    options: FfmpegDownloaderOption
    jobs: ptr seq[WorkerJob]
    results: ptr seq[DownloadResult]
    log: WewboLogger

proc toWorkerJob(item: FfmpegMediaInput): WorkerJob {.gcsafe.} =
  result = WorkerJob(
    video: item.media.video,
    typeExt: item.media.typeExt,
    hasHeaders: item.media.headers.isSome,
    headers: if item.media.headers.isSome: item.media.headers.get else: MediaHttpHeader(),
    hasSub: item.media.subtitle.isSome,
    subUrl: if item.media.subtitle.isSome: item.media.subtitle.get.url else: "",
    subTitle: if item.media.subtitle.isSome: item.media.subtitle.get.title else: "",
    subLang: if item.media.subtitle.isSome: item.media.subtitle.get.lang else: "",
    subExt: if item.media.subtitle.isSome: item.media.subtitle.get.ext else: sUnkown,
    outputName: item.outputName
  )

proc toMediaFormatData(job: WorkerJob): MediaFormatData {.gcsafe.} =
  result = MediaFormatData(
    video: job.video,
    typeExt: job.typeExt,
    headers: if job.hasHeaders: some(job.headers) else: none(MediaHttpHeader),
    subtitle:
      if job.hasSub:
        some(MediaSubtitle(
          title: job.subTitle,
          url: job.subUrl,
          lang: job.subLang,
          ext: job.subExt
        ))
      else:
        none(MediaSubtitle)
  )

proc workerLoop(state: ptr WorkerSharedState; workerId: int) {.gcsafe.} =
  while true:
    var idx = -1
    var job: WorkerJob
    var outdir: string
    var opts: FfmpegDownloaderOption
    var total: int
    withLock(state.lock):
      if state.nextIdx < state.total:
        idx = state.nextIdx
        inc state.nextIdx
        job = state.jobs[][idx]
        outdir = state.outdir
        opts = state.options
        total = state.total

    if idx < 0:
      break

    if not state.log.isNil:
      withLock(state.lock):
        state.log.info("[W$#] ($#/$#) Starting: $#" % [$workerId, $(idx + 1), $total, job.outputName])

    let media = job.toMediaFormatData()
    var res: DownloadResult
    try:
      let dl = newFfmpegDownloader(outdir, opts, logMode = mSilent)
      res = dl.downloadEpisode(media, job.outputName, label = "[$#/$#] $#" % [$(idx + 1), $total, job.outputName])
    except CatchableError as e:
      res = DownloadResult(
        outputName: job.outputName,
        outputPath: plannedOutputPath(outdir, job.outputName, media, opts),
        status: dsFailed,
        exitCode: 1,
        attempts: 1,
        errorMsg: e.msg
      )

    withLock(state.lock):
      state.results[][idx] = res
      if not state.log.isNil:
        case res.status
        of dsSuccess:
          state.log.text("[W$#] ($#/$#) Done: $#" % [$workerId, $(idx + 1), $total, extractFilename(res.outputPath)], color(fgGreen))
        of dsSkipped:
          state.log.text("[W$#] ($#/$#) Skipped (exists): $#" % [$workerId, $(idx + 1), $total, extractFilename(res.outputPath)], color(fgCyan))
        of dsFailed:
          state.log.warn("[W$#] ($#/$#) Failed: $# ($#)" % [$workerId, $(idx + 1), $total, job.outputName, res.errorMsg])

proc downloadAll*(
  outdir: string;
  options: FfmpegDownloaderOption;
  inputs: openArray[FfmpegMediaInput];
  workers: int = 1;
  log: WewboLogger = nil
): seq[DownloadResult] {.gcsafe.} =
  let total = inputs.len
  result = newSeq[DownloadResult](total)
  if total == 0:
    return

  let workerCount = clamp(workers, 1, min(8, total))
  if workerCount == 1:
    let mode = if log.isNil: mSilent else: mTui
    let dl = newFfmpegDownloader(outdir, options, logMode = mode)
    for idx, item in inputs:
      let lbl = "[$#/$#] $#" % [$(idx + 1), $total, sanitizeFilename(item.outputName)]
      result[idx] = dl.downloadEpisode(item.media, item.outputName, label = lbl)
      if not log.isNil:
        case result[idx].status
        of dsSuccess:
          log.text("[DL] ($#/$#) Success: $#" % [$(idx + 1), $total, extractFilename(result[idx].outputPath)], color(fgGreen))
        of dsSkipped:
          log.text("[DL] ($#/$#) Skipped (exists): $#" % [$(idx + 1), $total, extractFilename(result[idx].outputPath)], color(fgCyan))
        of dsFailed:
          log.warn("[DL] ($#/$#) Failed: $# ($#)" % [$(idx + 1), $total, item.outputName, result[idx].errorMsg])
  else:
    var jobSeq = newSeq[WorkerJob](total)
    for i, item in inputs:
      jobSeq[i] = item.toWorkerJob()

    var state = WorkerSharedState(
      nextIdx: 0,
      total: total,
      outdir: outdir,
      options: options,
      jobs: addr jobSeq,
      results: addr result,
      log: log
    )
    initLock(state.lock)
    defer: deinitLock(state.lock)

    var m = createMaster()
    m.awaitAll:
      for w in 1 .. workerCount:
        m.spawn workerLoop(addr state, w)

proc downloadAll*(ffmpeg: FfmpegDownloader; inputs: openArray[FfmpegMediaInput]): seq[int] {.gcsafe.} =
  ## Legacy-compatible wrapper returning exit codes.
  let results = downloadAll(ffmpeg.outdir, ffmpeg.options, inputs, workers = 1, log = ffmpeg.log)
  for r in results:
    result.add(r.exitCode)

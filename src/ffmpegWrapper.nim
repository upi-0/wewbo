import
  os,
  options,
  strutils,
  sequtils,
  tables

import
  ./process,
  ./media/types,
  ./tui/logger

type
  FfmpegWrapperOption* = tuple[
    crf: int = 28,
    fps: int = 25,
    sub: bool = true,
  ]

  FfmpegWrapper* = ref object of CliApplication
    outdir*: string
    targetExt: string = "mp4"
    options*: FfmpegWrapperOption

proc newFfmpegWrapper*(outdir: string; options: FfmpegWrapperOption; logMode: WewboLogMode = mTui): FfmpegWrapper =
  result = FfmpegWrapper(name: "ffmpeg", outdir: outdir, options: options, logMode: logMode).setUp()

method failureHandler(ffmpeg: FfmpegWrapper, context: CLiError) =
  raise newException(ValueError, "ffmpeg is not detected on your system.")

method specialLineCb(cli: CliApplication) : SpecialLineProc =
  (
    proc (x: string) : bool =
      x.contains("frame=")
  )

# Generic wrapper API
proc resetArgs*(ffmpeg: FfmpegWrapper) =
  ffmpeg.args = @[]

proc addFlag*(ffmpeg: FfmpegWrapper; flag: string) =
  ffmpeg.addArg(flag)

proc addOption*(ffmpeg: FfmpegWrapper; key, value: string) =
  ffmpeg.addArg(key)
  ffmpeg.addArg(value)

proc addInput*(ffmpeg: FfmpegWrapper; input: string) =
  ffmpeg.addOption("-i", input)

proc addOutput*(ffmpeg: FfmpegWrapper; output: string) =
  ffmpeg.addArg(output)

proc addVideoCodec*(ffmpeg: FfmpegWrapper; codec = "libx264") =
  ffmpeg.addOption("-vcodec", codec)

proc addCrf*(ffmpeg: FfmpegWrapper; crf: int) =
  ffmpeg.addOption("-crf", $crf)

proc addFps*(ffmpeg: FfmpegWrapper; fps: int) =
  ffmpeg.addOption("-r", $fps)

proc addFilter*(ffmpeg: FfmpegWrapper; value: string) =
  ffmpeg.addOption("-vf", value)

proc run*(ffmpeg: FfmpegWrapper; message = "Executing ffmpeg"; clearArgs = true) : int =
  ffmpeg.execute(message = message, clearArgs = clearArgs)

proc runWithArgs*(ffmpeg: FfmpegWrapper; args: openArray[string]; message = "Executing ffmpeg"; clearArgs = true) : int =
  for arg in args:
    ffmpeg.addArg(arg)

  ffmpeg.run(message = message, clearArgs = clearArgs)

# Media helpers for this project
proc setHeader(ffmpeg: FfmpegWrapper, ty, val: string) =
  let ngantukCok = {
    "userAgent" : "User-Agent",
    "referer" : "Referer",
    "cookie" : "Cookie"
  }.toTable

  ffmpeg.addOption("-headers", "$#: $#" % [ngantukCok[ty], val])

proc setUpMediaHeader*(ffmpeg: FfmpegWrapper, headers: Option[MediaHttpHeader]) =
  if headers.isNone :
    return

  for chi, no in headers.get.fieldPairs() :
    if no != "" :
      ffmpeg.setHeader(chi, no)

proc setDefaultEncoding*(ffmpeg: FfmpegWrapper) =
  ffmpeg.addVideoCodec()
  ffmpeg.addCrf(ffmpeg.options.crf)
  ffmpeg.addFps(ffmpeg.options.fps)

proc setMediaInput*(ffmpeg: FfmpegWrapper, media: MediaFormatData) =
  ffmpeg.addInput(media.video)

proc sanitizeOutputName*(name: string) : string =
  const nega = ["[", "]", "/", "\\", "?", ","]
  result = name.replace(" ", "-")

  for ne in nega:
    result = result.replace(ne)

proc buildTargetPath*(ffmpeg: FfmpegWrapper, output: string) : string =
  if not dirExists(ffmpeg.outdir) :
    createDir(ffmpeg.outdir)

  "$#.$#" % [ffmpeg.outdir / output.sanitizeOutputName(), ffmpeg.targetExt]

proc setMediaOutput*(ffmpeg: FfmpegWrapper, output: string) =
  ffmpeg.addOutput(ffmpeg.buildTargetPath(output))

proc downloadSubtitleAsAss*(ffmpeg: FfmpegWrapper, subtitleUrl: string; tempFile = "wewbo_sub_file.ass") : int =
  ffmpeg.runWithArgs([
    "-i", subtitleUrl,
    "-c:s", "ass",
    tempFile
  ], message = "Downloading Subtitle...")

proc deleteTempFile {.nimcall.} = removeFile("wewbo_sub_file.ass")

proc downloadMedia*(ffmpeg: FfmpegWrapper, input: MediaFormatData, output: string) : int =
  if input.subtitle.isSome and ffmpeg.options.sub:
    ffmpeg.log.info("Extracting subtitle.")

    if ffmpeg.downloadSubtitleAsAss(input.subtitle.get.url) < 1:
      ffmpeg.setUpMediaHeader(input.headers)
      ffmpeg.setMediaInput(input)
      ffmpeg.addFilter("ass=wewbo_sub_file.ass")
    else:
      raise newException(ValueError, "Gagal Download Subtitle Jir")
  else:
    ffmpeg.setUpMediaHeader(input.headers)
    ffmpeg.setMediaInput(input)

  ffmpeg.setDefaultEncoding()
  ffmpeg.setMediaOutput(output)

  ffmpeg.execute("Downloading " & output, after = some(deleteTempFile))

proc downloadMedias*(ffmpeg: FfmpegWrapper, inputs: openArray[MediaFormatData], outputs: openArray[string]) : seq[int] =
  assert inputs.len == outputs.len

  ffmpeg.log.info("Downloading Options: " & $ffmpeg.options)
  sleep(3_000)

  for (input, output) in zip(inputs, outputs) :
    result.add(ffmpeg.downloadMedia(input, output))

# Backward-compatible aliases
proc download*(ffmpeg: FfmpegWrapper, input: MediaFormatData, output: string) : int =
  ffmpeg.downloadMedia(input, output)

proc downloadAll*(ffmpeg: FfmpegWrapper, inputs: openArray[MediaFormatData], outputs: openArray[string]) : seq[int] =
  ffmpeg.downloadMedias(inputs, outputs)

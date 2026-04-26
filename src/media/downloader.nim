import
  ../ffmpegWrapper as ffw

import
  ../media/types,
  ../tui/logger

type
  FfmpegDownloaderOption* = ffw.FfmpegWrapperOption
  FfmpegDownloader* = ffw.FfmpegWrapper

proc newFfmpegDownloader*(outdir: string; options: FfmpegDownloaderOption; logMode: WewboLogMode = mTui) : FfmpegDownloader =
  ffw.newFfmpegWrapper(outdir = outdir, options = options, logMode = logMode)

proc download*(ffmpeg: FfmpegDownloader, input: MediaFormatData, output: string) : int =
  ffw.download(ffmpeg, input, output)

proc downloadAll*(ffmpeg: FfmpegDownloader, inputs: openArray[MediaFormatData], outputs: openArray[string]) : seq[int] =
  ffw.downloadAll(ffmpeg, inputs, outputs)

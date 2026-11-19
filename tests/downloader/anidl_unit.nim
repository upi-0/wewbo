import
  unittest, os, osproc, streams, options, strutils, json

import
  media/[downloader, format, types],
  extractor/[all, types],
  app/ani_dl/main as anidl,
  terminal/paramarg,
  opt,
  tui/logger

proc generateSampleMedia(dir: string): tuple[videoPath, vttPath: string] =
  createDir(dir)
  result.videoPath = dir / "sample_input.mp4"
  result.vttPath = dir / "sample_sub.vtt"

  let (outp, code) = execCmdEx(
    "ffmpeg -y -hide_banner -loglevel error " &
    "-f lavfi -i color=c=black:s=160x120:d=1 " &
    "-f lavfi -i anullsrc=r=44100:cl=mono -t 1 " &
    "-c:v libx264 -pix_fmt yuv420p -c:a aac " &
    quoteShell(result.videoPath)
  )
  doAssert code == 0, "Failed to generate sample video: " & outp

  writeFile(result.vttPath, """WEBVTT

00:00:00.000 --> 00:00:00.900
Hello Wewbo Ani-DL
""")

suite "Episode Spec Parser":
  test "parses all, single, ranges, open-ended, and comma lists":
    check parseEpisodeSpec("", 5) == @[1, 2, 3, 4, 5]
    check parseEpisodeSpec("all", 4) == @[1, 2, 3, 4]
    check parseEpisodeSpec("3", 10) == @[3]
    check parseEpisodeSpec("2-5", 10) == @[2, 3, 4, 5]
    check parseEpisodeSpec("8-", 10) == @[8, 9, 10]
    check parseEpisodeSpec("-3", 10) == @[1, 2, 3]
    check parseEpisodeSpec("1, 3, 5-7, 3, 6", 10) == @[1, 3, 5, 6, 7]

  test "rejects invalid or out-of-bounds specs":
    expect ValueError:
      discard parseEpisodeSpec("0", 10)
    expect ValueError:
      discard parseEpisodeSpec("11", 10)
    expect ValueError:
      discard parseEpisodeSpec("6-2", 10)
    expect ValueError:
      discard parseEpisodeSpec("abc", 10)
    expect ValueError:
      discard parseEpisodeSpec("1", 0)

suite "Filename Sanitization & Episode Padding":
  test "sanitizes cross-platform forbidden characters":
    check sanitizeFilename("Re:Zero / Ep? [1080p]*") == "ReZero-Ep-1080p"
    check sanitizeFilename("  ..///::  ") == "episode"
    check sanitizeFilename("Slow Loop: Episode 1") == "Slow-Loop-Episode-1"

  test "zero-pads episode names":
    check formatEpisodeOutputName("Episode 1", 1, 12) == "Episode-01"
    check formatEpisodeOutputName("Episode 12", 12, 12) == "Episode-12"
    check formatEpisodeOutputName("Episode 5", 5, 120) == "Episode-005"
    check formatEpisodeOutputName("7", 7, 24) == "Episode-07"
    check formatEpisodeOutputName("[1] Pilot Episode", 1, 12) == "1-Pilot-Episode"

suite "Format Detection & Smart Matching":
  test "detects resolution heights accurately":
    check detectResolutionHeight("1920x1080 sun") == 1080
    check detectResolutionHeight("1280x720 kiwi") == 720
    check detectResolutionHeight("m720p pdrain") == 720
    check detectResolutionHeight("Ak - 480") == 480
    check detectResolutionHeight("4K UHD") == 2160
    check format.detectResolution("1920x1080 sun") == rBest
    check format.detectResolution("1280x720 kiwi") == rGood
    check format.detectResolution("854x480 hop") == rBad

  test "detects extensions case-insensitively":
    check detectExt("https://cdn.example/video.m3u8?token=abc") == extM3u8
    check detectExt("Episode_01.MKV") == extMkv
    check detectExt("video.mp4") == extMp4
    check detectExt("1920x1080 sun") == extNone

  test "prefers same server and resolution in findBestMatch":
    let fmts = @[
      ExFormatData(title: "1920x1080 sun", format_identifier: "u1"),
      ExFormatData(title: "1920x1080 kiwi", format_identifier: "u2"),
      ExFormatData(title: "1280x720 kiwi", format_identifier: "u3")
    ]
    check findBestMatch(fmts, "1080p kiwi", allowInteractive = false).format_identifier == "u2"
    check findBestMatch(fmts, "1920x1080 sun", allowInteractive = false).format_identifier == "u1"

  test "matches CLI quality preferences":
    let fmts = @[
      ExFormatData(title: "640x360 sun", format_identifier: "360"),
      ExFormatData(title: "1280x720 sun", format_identifier: "720"),
      ExFormatData(title: "1920x1080 sun", format_identifier: "1080")
    ]
    check matchQualityPreference(fmts, "best").get.format_identifier == "1080"
    check matchQualityPreference(fmts, "worst").get.format_identifier == "360"
    check matchQualityPreference(fmts, "720").get.format_identifier == "720"
    check matchQualityPreference(fmts, "480").get.format_identifier == "360"

suite "Subtitle Matching":
  test "matches by exact title then substring case-insensitively":
    let subs = @[
      MediaSubtitle(title: "Spanish (Latin America)", url: "es.vtt"),
      MediaSubtitle(title: "English - US", url: "en.vtt"),
      MediaSubtitle(title: "Indonesian", url: "id.vtt")
    ]
    check matchSubtitle(subs, "indonesian").get.url == "id.vtt"
    check matchSubtitle(subs, "english").get.url == "en.vtt"
    check matchSubtitle(subs, "french").isNone

suite "Downloader Helpers":
  test "builds unified CRLF header string including Origin":
    let hdr = MediaHttpHeader(
      userAgent: "TestUA/1.0",
      referer: "https://miruro.cx/",
      cookie: "a=1",
      origin: "https://miruro.cx"
    )
    let built = buildHeaderString(some(hdr))
    check built == "User-Agent: TestUA/1.0\r\nReferer: https://miruro.cx/\r\nCookie: a=1\r\nOrigin: https://miruro.cx\r\n"
    check buildHeaderString(none(MediaHttpHeader)) == ""

  test "resolves container extensions safely (never empty or m3u8)":
    let hlsWithSub = MediaFormatData(
      video: "https://example.com/master.m3u8",
      typeExt: extM3u8,
      subtitle: some(MediaSubtitle(title: "English", url: "sub.vtt", ext: sVtt))
    )
    let hlsNoSub = MediaFormatData(video: "https://example.com/master.m3u8", typeExt: extM3u8)

    check resolveTargetExt(hlsWithSub, FfmpegDownloaderOption(subtitleMode: smSoft, container: cfAuto)) == "mkv"
    check resolveTargetExt(hlsWithSub, FfmpegDownloaderOption(subtitleMode: smSoft, container: cfMp4)) == "mp4"
    check resolveTargetExt(hlsWithSub, FfmpegDownloaderOption(subtitleMode: smHard, container: cfAuto)) == "mp4"
    check resolveTargetExt(hlsNoSub, FfmpegDownloaderOption(subtitleMode: smSoft, container: cfAuto)) == "mp4"
    check resolveTargetExt(MediaFormatData(video: "x", typeExt: extNone), FfmpegDownloaderOption()) == "mp4"

  test "parses FFmpeg duration, time, speed, and renders progress bar":
    check parseFfmpegDuration("  Duration: 00:23:50.50, start: 0.000000") == 1430.5
    check parseFfmpegTime("frame=  120 fps= 60 time=00:01:10.00 bitrate=1234kbits/s speed=4.2x") == 70.0
    check parseFfmpegSpeed("frame=  120 time=00:01:10.00 speed=4.2x   ") == "4.2x"
    let bar = renderProgressBar("[1/12] Ep-01", 60.0, 120.0, "4.2x")
    check bar.contains("50%")
    check bar.contains("01:00/02:00")
    check bar.contains("4.2x")

suite "CLI Paramarg & OptionArgs Fixes":
  test "paramarg parses explicit boolean values and flags":
    var fa = loadArguments(@["--overwrite:true", "--reencode:false", "-y", "My Anime"])
    fa.add(@[
      option("--overwrite", "overwrite", "Overwrite", false),
      option("--reencode", "reencode", "Reencode", true),
      option("-y", "yes", "Yes", false)
    ])
    fa.parse()
    check fa["overwrite"].getBool() == true
    check fa["reencode"].getBool() == false
    check fa["yes"].getBool() == true
    check fa.nargs == @["My Anime"]

  test "OptionArgs putRange has no duplicate entries and applies defaults":
    var oa = OptionArgs()
    oa.putRange(1, 5, "End", default = 5)
    oa.putBool("Overwrite", default = false)
    oa.applyDefaults()
    check oa["End"].n == 5
    check oa["Overwrite"].b == false

suite "End-to-End Local FFmpeg Pipeline":
  test "softsub MKV, hardsub MP4, external sidecar, resume/skip, overwrite, and parallel workers":
    let baseTmp = getTempDir() / "wewbo_anidl_e2e_test"
    if dirExists(baseTmp):
      removeDir(baseTmp)
    let (vidPath, subPath) = generateSampleMedia(baseTmp / "src")
    defer:
      if dirExists(baseTmp):
        removeDir(baseTmp)

    let sub = MediaSubtitle(title: "English", url: subPath, ext: sVtt)
    let mediaWithSub = MediaFormatData(video: vidPath, typeExt: extMp4, subtitle: some(sub))

    # 1. Softsub + keepFormat -> MKV
    let softDir = baseTmp / "soft"
    let softOpts = FfmpegDownloaderOption(subtitleMode: smSoft, keepFormat: true, container: cfAuto, retries: 0)
    let softDl = newFfmpegDownloader(softDir, softOpts, logMode = mSilent)
    let rSoft = softDl.downloadEpisode(mediaWithSub, "Episode-01")
    check rSoft.status == dsSuccess
    check rSoft.outputPath.endsWith("Episode-01.mkv")
    check fileExists(rSoft.outputPath) and getFileSize(rSoft.outputPath) > 0

    # 2. Resume skips existing file when overwrite == false
    let rSkip = softDl.downloadEpisode(mediaWithSub, "Episode-01")
    check rSkip.status == dsSkipped
    check rSkip.attempts == 0

    # 3. Overwrite re-downloads when overwrite == true
    var ovOpts = softOpts
    ovOpts.overwrite = true
    let ovDl = newFfmpegDownloader(softDir, ovOpts, logMode = mSilent)
    let rOv = ovDl.downloadEpisode(mediaWithSub, "Episode-01")
    check rOv.status == dsSuccess
    check rOv.attempts == 1

    # 4. Hardsub (must NOT fail with -vf + -c copy even if keepFormat == true)
    let hardDir = baseTmp / "hard"
    let hardOpts = FfmpegDownloaderOption(subtitleMode: smHard, keepFormat: true, container: cfAuto, crf: 28, retries: 0)
    let hardDl = newFfmpegDownloader(hardDir, hardOpts, logMode = mSilent)
    let rHard = hardDl.downloadEpisode(mediaWithSub, "Episode-01")
    check rHard.status == dsSuccess
    check rHard.outputPath.endsWith("Episode-01.mp4")
    check fileExists(rHard.outputPath) and getFileSize(rHard.outputPath) > 0

    # 5. External sidecar subtitle
    let extDir = baseTmp / "external"
    let extOpts = FfmpegDownloaderOption(subtitleMode: smExternal, keepFormat: true, container: cfMp4, retries: 0)
    let extDl = newFfmpegDownloader(extDir, extOpts, logMode = mSilent)
    let rExt = extDl.downloadEpisode(mediaWithSub, "Episode-01")
    check rExt.status == dsSuccess
    check fileExists(extDir / "Episode-01.mp4")
    check fileExists(extDir / "Episode-01.vtt")

    # 6. Parallel downloadAll (workers = 2) with 3 clips & softsubs
    let parDir = baseTmp / "parallel"
    let parOpts = FfmpegDownloaderOption(subtitleMode: smSoft, keepFormat: true, container: cfMkv, retries: 0)
    let batch: seq[FfmpegMediaInput] = @[
      (media: mediaWithSub, outputName: "Episode-01", formatIdentity: detectFormat("1080p")),
      (media: mediaWithSub, outputName: "Episode-02", formatIdentity: detectFormat("1080p")),
      (media: mediaWithSub, outputName: "Episode-03", formatIdentity: detectFormat("1080p"))
    ]
    let parRes = downloadAll(parDir, parOpts, batch, workers = 2, log = nil)
    check parRes.len == 3
    for r in parRes:
      check r.status == dsSuccess
      check fileExists(r.outputPath) and getFileSize(r.outputPath) > 0

  test "HTTP HLS with disguised .jpg segments and .jpeg VTT subtitle":
    let pyExe = findExe("python3")
    if pyExe.len == 0:
      skip()
    else:
      let baseTmp = getTempDir() / "wewbo_anidl_hls_http_test"
      if dirExists(baseTmp):
        removeDir(baseTmp)
      let (vidPath, subPath) = generateSampleMedia(baseTmp / "src")
      defer:
        if dirExists(baseTmp):
          removeDir(baseTmp)

      let srvDir = baseTmp / "srv"
      createDir(srvDir)
      let segPath = srvDir / "seg0.jpg"
      let (_, segCode) = execCmdEx(
        "ffmpeg -y -hide_banner -loglevel error -i " & quoteShell(vidPath) &
        " -c copy -f mpegts " & quoteShell(segPath)
      )
      require segCode == 0
      copyFile(subPath, srvDir / "sub.jpeg")
      writeFile(srvDir / "master.m3u8", "#EXTM3U\n#EXT-X-VERSION:3\n#EXT-X-TARGETDURATION:2\n#EXTINF:1.0,\nseg0.jpg\n#EXT-X-ENDLIST\n")

      let srvScript = baseTmp / "srv.py"
      writeFile(srvScript, """
import functools, http.server, sys
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *args): pass
    def do_GET(self):
        if self.headers.get("Referer") != "https://example.test/":
            self.send_error(403, "Missing Referer")
            return
        super().do_GET()
h = functools.partial(Handler, directory=sys.argv[1])
s = http.server.ThreadingHTTPServer(("127.0.0.1", 0), h)
print(s.server_address[1], flush=True)
s.serve_forever()
""")

      let srvProc = startProcess(pyExe, args = [srvScript, srvDir], options = {poStdErrToStdOut})
      defer:
        srvProc.terminate()
        discard srvProc.waitForExit()
        srvProc.close()

      let portLine = srvProc.outputStream().readLine().strip()
      let port = parseInt(portLine)
      let baseUrl = "http://127.0.0.1:" & $port
      let hdrs = MediaHttpHeader(referer: "https://example.test/", origin: "https://example.test")
      let hlsMedia = MediaFormatData(
        video: baseUrl & "/master.m3u8",
        typeExt: extM3u8,
        headers: some(hdrs),
        subtitle: some(MediaSubtitle(title: "English", url: baseUrl & "/sub.jpeg", ext: sUnkown))
      )

      let outDir = baseTmp / "out"
      let dlOpts = FfmpegDownloaderOption(subtitleMode: smSoft, keepFormat: true, container: cfAuto, retries: 0)
      let dl = newFfmpegDownloader(outDir, dlOpts, logMode = mSilent)
      let res = dl.downloadEpisode(hlsMedia, "Episode-01")
      check res.status == dsSuccess
      check res.outputPath.endsWith("Episode-01.mkv")
      check fileExists(res.outputPath) and getFileSize(res.outputPath) > 0

import
  main,
  terminal/[command, paramarg]

const
  name = "ani-dl"
  help = "Ani-DL. Anime Downloader"
  entry = download2

proc anidlCommand*: SubCommand {.gcsafe.} =
  let
    commands = @[
      option("-s", "source", "Select Source", "mori"),
      option("-e", "episodes", "Episode spec (e.g. 1-12, 1,3,5-8, all)", ""),
      option("-o", "outdir", "Output directory", ""),
      option("-q", "quality", "Quality preference (best, 1080, 720, 480, worst)", ""),
      option("--sub", "sub_mode", "Subtitle mode (soft, hard, external, none)", "soft"),
      option("--sub-lang", "sub_lang", "Preferred subtitle language/label", ""),
      option("--format", "container", "Output container (auto, mp4, mkv)", "auto"),
      option("--reencode", "reencode", "Re-encode video instead of stream copy", false),
      option("--crf", "crf", "FFmpeg CRF quality for re-encoding (0-51)", 23),
      option("--fps", "fps", "Target FPS when re-encoding (0 = source)", 0),
      option("-j", "workers", "Concurrent download workers (1-8)", 1),
      option("--retries", "retries", "Retry attempts per failed episode", 2),
      option("--overwrite", "overwrite", "Overwrite already-downloaded episodes", false),
      option("--ffmpeg", "ffmpeg_path", "Custom path to ffmpeg binary", "ffmpeg"),
      option("-y", "yes", "Non-interactive mode (skip option menu)", false)
    ]
  result = newSubCommand(
    name = name,
    help = help,
    entry = entry,
    argOpts = commands
  )

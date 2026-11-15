import
  macros,
  os,
  strutils

import
  ./process,
  ./tui/logger

const
  qjsExeName = when defined(windows): "qjs.exe" else: "qjs"

type
  JSRuntime* = ref object of CliApplication

method failureHandler(js: JSRuntime, context: CliError) {.gcsafe.} =
  if context == erCommandNotFound:
    raise newException(ValueError, "$# is not detected on your system or in app directory." % js.name)

proc qjsAssetName(): string {.compileTime.} =
  when defined(windows):
    when defined(amd64): "qjs-windows-x86_64.exe"
    elif defined(i386): "qjs-windows-x86.exe"
    else: {.error: "Unsupported Windows architecture for QuickJS".}
  elif defined(linux):
    when defined(amd64): "qjs-linux-x86_64"
    elif defined(arm64): "qjs-linux-aarch64"
    elif defined(i386): "qjs-linux-x86"
    elif defined(arm): "qjs-linux-armv7"
    elif defined(riscv64): "qjs-linux-riscv64"
    else: {.error: "Unsupported Linux architecture for QuickJS".}
  elif defined(macosx):
    when defined(arm64): "qjs-darwin-arm64"
    elif defined(amd64): "qjs-darwin-x86_64"
    else: {.error: "Unsupported macOS architecture for QuickJS".}
  else:
    {.error: "Unsupported OS for QuickJS".}

proc fetchQjs*(): string {.compileTime.} =
  ## Locate an existing `qjs` binary locally (current/project/build dir or `PATH`)
  ## or download the latest release from `quickjs-ng/quickjs` at compile time.
  
  when not defined(release):
    let candidates = [
      getProjectPath() / "qjs",
      getProjectPath() / "build" / "qjs",
      "qjs"
    ]
    for candidate in candidates:
      let found = findExe(candidate)
      if found.len > 0 and fileExists(found):
        return readFile(found)

  let
    asset = qjsAssetName()
    downloadPath = getTempDir() / asset
    url = "https://github.com/quickjs-ng/quickjs/releases/latest/download/" & asset
    (output, exitCode) = gorgeEx("curl -fsSL -o " & quoteShell(downloadPath) & " " & quoteShell(url))
  if exitCode != 0:
    raise newException(IOError, "Failed to fetch QuickJS from " & url & ": " & output)
  readFile(downloadPath)

const
  qjsBinary = fetchQjs()

proc putQjs*(): string =
  ## Write the embedded QuickJS binary to the user cache directory and return its path.
  let cacheDir = getCacheDir("wewbo")
  createDir(cacheDir)
  result = cacheDir / qjsExeName
  if not fileExists(result) or getFileSize(result) != qjsBinary.len:
    writeFile(result, qjsBinary)
  when not defined(windows):
    inclFilePermissions(result, {fpUserExec})

proc newJSRuntime*(name: string = "qjs", logMode: WewboLogMode = mTui): JSRuntime =
  ## Create and initialize a QuickJS (`qjs`) runtime wrapper.
  ## Extracts the embedded `qjs` to the cache directory when `name == "qjs"`.
  let resolvedName =
    if name == "qjs":
      putQjs()
    else:
      let appDirExe = getAppDir() / name
      if findExe(appDirExe) != "": appDirExe else: name

  result = JSRuntime(
    name: resolvedName,
    logMode: logMode
  ).setUp()

proc runCaptured(js: JSRuntime, workingDir: string): string =
  let (output, exitCode) = js.executeOutput(workingDir = workingDir)
  if exitCode != 0:
    raise newException(ValueError, "JSRuntime failed with exit code $#: $#" % [$exitCode, output.strip()])
  output.strip()

proc eval*(js: JSRuntime, script: string, std: bool = true, workingDir: string = getAppDir()): string =
  ## Evaluate an inline JavaScript snippet and return its trimmed stdout.
  if std:
    js.addArg("--std")
  js.addArg("-e")
  js.addArg(script)
  js.runCaptured(workingDir)

proc runFile*(js: JSRuntime, path: string, std: bool = true, workingDir: string = getAppDir()): string =
  ## Execute a JavaScript file and return its trimmed stdout.
  if std:
    js.addArg("--std")
  js.addArg(path)
  js.runCaptured(workingDir)

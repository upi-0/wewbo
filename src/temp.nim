import os, strutils, oids
import tui/logger

type TempManager* = ref object of RootObj
  dir: string
  log: WewboLogger

iterator all*(temp: TempManager): string =
  for tempFile in walkFiles(temp.dir / "*"):
    if tempFile.contains("wewbo-"):
      yield tempFile

proc clearAll*(temp: TempManager): void =
  for tempFile in temp.all:
    temp.log.info("Deleting: " & tempFile)
    tempFile.removeFile()

proc write*(temp: TempManager; content: string; prefix = ""): string =
  temp.log.info("Write Temp: " & content.split("\n")[0] & "...")
  result = temp.dir / "wewbo-" & $genOid() & prefix
  result.writeFile(content)

proc newTempManager*(dir = getTempDir(), logMode = mTui): TempManager =
  result = TempManager()
  result.dir = dir
  result.log = useWewboLogger("temp", mode=logMode)

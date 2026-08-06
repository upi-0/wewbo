import  
  streams, strutils, sequtils, os

import
  terminal/[command, paramarg],
  translator/all,
  tui/logger,
  languages,
  htmlentity,
  temp

import
  ./[ext, types]  

proc getRawSubtitle(path: string) : string =
  newFileStream(path, fmRead).readAll()

proc realTranslate(translator: Translator; input: seq[LineContent]; sourceLang: Languages; chunkLen = 5): seq[ChunkedLineContent] =
  let
    rijal = input.distribute(chunkLen)
    seperator = " ||| "

  var
    hasil: seq[string]
    idxes: seq[int]

  for i, chunk in rijal:
    translator.log.info "Translating Chunk " & $(i + 1)
    hasil.reset()
    idxes.reset()

    for r in chunk:
      hasil.add(r.text)
      idxes.add(r.idx)

    result.add (
      idxes: idxes,
      translatedLines: translator.translate(hasil.join seperator, sourceLang).split seperator,
      rawLines: hasil
    )  

proc subtl(translator: Translator; inputFile, outputFile: string; sourceLang: Languages; toTemp = false) : string =
  let
    (_, fileName, extName) = splitFile inputFile
    subtitleContent = getRawSubtitle inputFile

  if not availableHandlers.contains(extName):
    echo "Not supported format: " & extName
    quit(1)

  let
    rawChunk = handlers[extName] subtitleContent
    translatedChunk = translator.realTranslate(rawChunk, sourceLang)

  var
    hasil = subtitleContent.splitLines()
    outFile = outputFile
    strhasil: string

  for chunk in translatedChunk:
    for (i, supami) in zip(chunk.idxes, zip(chunk.translatedLines, chunk.rawLines)):
      hasil[i] = hasil[i]
        .replace(supami[1], supami[0]) # Replace to translated line.
        .encode()
      echo hasil[i]  

  strhasil = hasil.join("\n")      

  if toTemp:
    let temp = newTempManager("teel", logMode=mEcho)
    return temp.write(strhasil, extName)

  elif outFile.len == 0:
    outFile = fileName & "-" & translator.outputLang.getCountryCode() & extName

  writeFile(outFile, strhasil)

proc teel*(f: FullArgument) {.gcsafe.} =
  var
    subtitleFileName: string
  
  if f.nargs.len == 0:
    echo "Filename couldn't be empty"
    quit(1)

  elif not f.nargs[0].fileExists():
    echo "File not found: " & f.nargs[0]
    quit(1)

  else:
    subtitleFileName = f.nargs[0]

  let
    outLang = f["tl"].getStr().getLang()
    translator = getTranslator("google", outLang, mode=mEcho)

  block setMainInput:    
    let
      inputFile = subtitleFileName
      outputFile = f["output-file"].getStr()
      sourceLang = f["sl"].getStr().getLang()
      toTemp = f["temp"].getBool()

    block logInput:
      translator.log.info("Input File: " & inputFile)
      translator.log.info("Output File: " & outputFile)
      translator.log.info("Source Lang: " & $sourceLang)
      translator.log.info("Target Lang: " & $outLang)

    echo translator.subtl(
      inputFile, outputFile, sourceLang, toTemp
    )

let teelCommand* = newSubCommand(
  "teel", teel,  @[
    option("-sl", "sl", tString, "english", "source language"),
    option("-tl", "tl", tString, "english", "target language"),
    option("-o", "output-file", tString, help="output file"),
    option("-p", "provider", tString, "google", "translate provider: google, gemini, openai (API)"),
    option("-pkey", "provider-key", tString, help="provider key (Put API_KEY here)"),
    option("--temp", "temp", tBool, false, "Store to temp"),
    option("--config", "config-file", tString, "", "Address to config file (JSON based)")
  ], "translate subtitle file."
)

when isMainModule:
  @[teelCommand].start()

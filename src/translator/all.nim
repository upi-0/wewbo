import
  tables, sequtils, strutils

import translators/[
  google,
  gemini,
  openai
]

import
  ../tui/logger,
  base

type
  LoaderTranslatorProc = proc(tl: var Translator) {.gcsafe.}
  LoaderTranslatorProcs = Table[string, LoaderTranslatorProc]

proc loaderTranslaterProcs: LoaderTranslatorProcs =
  result["google"] = newGoogleTranslator
  result["gemini"] = newGeminiTranslator
  result["openai"] = newOpenaiTranslator

const
  tlLoader = loaderTranslaterProcs()
  tlList = tlLoader.keys.toSeq()

proc getTranslator*(name: string; outputLang: Languages; mode: WewboLogMode = mTui) : Translator =
  if not tlList.contains(name):
    raise newException(ValueError, "Invalid translator: '$#'" % name)

  tlLoader[name](result)
  result.init(outputLang, mode=mode)

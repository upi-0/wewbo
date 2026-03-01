from tables import
  Table,
  hasKey,
  keys,
  `[]`,
  `[]=`

from strutils import replace

proc htmlEntityDict: Table[string, string] {.compileTime.} =
  result["&quot;"] = "\""
  result["&apos;"] = "'"
  result["&lt;"]   = "<"
  result["&gt;"]   = ">"
  result["&amp;"]  = "&"
  result["&nbsp;"] = " "
  result["&copy;"] = "©"
  result["&reg;"]  = "®"
  result["&trade;"] = "™"
  result["&hellip;"] = "…"
  result["&mdash;"] = "—"
  result["&ldquo;"] = "“"
  result["&rdquo;"] = "”"

const htmlEntity = htmlEntityDict()

proc encode*(word: string): string =   
  result = word
  for ent in htmlEntity.keys():
    result = result.replace(ent, htmlEntity[ent])

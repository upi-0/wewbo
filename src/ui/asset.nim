import pkg/illwill
import std/[terminal, strutils]

proc renderBanner*(tb: var TerminalBuffer) =
  ## Render ASCII art banner
  let x = (tb.width - 36) div 2
  
  tb.write(x, 0, fgWhite, styleBright, "                        _           ")
  tb.write(x, 1, fgWhite, styleBright, "                       | |          ")
  tb.write(x, 2, fgWhite, styleBright, " __      _______      _| |__   ___  ")
  tb.write(x, 3, fgWhite, styleBright, " \\ \\ /\\ / / _ \\ \\ /\\ / / '_ \\ / _ \\ ")
  tb.write(x, 4, fgWhite, styleBright, "  \\ V  V /  __/\\ V  V /| |_) | (_) |")
  tb.write(x, 5, fgWhite, styleBright, "   \\_/\\_/ \\___| \\_/\\_/ |_.__/ \\___/ ")

proc renderBanner*(tb: var TerminalBuffer, termWidth: int) {.deprecated.} = renderBanner(tb)  

proc crop(tb: var TerminalBuffer; text: var string) =
  if text.len >= tb.width - 8:
    text = text[0 .. tb.width - 2 - 8]
    text &= "..."

  text = text.replace("\r", "")
  text.stripLineEnd()

proc renderTopBorder*(tb: var TerminalBuffer, yPos: int, title: string = "Rijal Ke Sukabumi") =
  var pageInfo = " $# " % [title]
  tb.crop(pageInfo)
  
  let
    termWidth = tb.width
    leftPad = (termWidth - pageInfo.len - 2) div 2
    rightPad = termWidth - pageInfo.len - leftPad - 2

  tb.write(0, yPos, fgCyan, "╔" & "═".repeat(leftPad))
  tb.write(leftPad + 1, yPos, fgYellow, pageInfo)
  tb.write(leftPad + pageInfo.len + 1, yPos, fgCyan, "═".repeat(rightPad) & "╗")  

proc renderBottomBorder*(tb: var TerminalBuffer, termWidth: int, yPos: int) =
  tb.write(0, yPos, fgCyan, "╚" & "═".repeat(termWidth - 2) & "╝")

proc renderEmptyRows*(tb: var TerminalBuffer, termWidth: int, startRow: int, 
                     endRow: int) =
  ## Fill empty rows jika items kurang dari page size
  var row = startRow
  while row <= endRow:
    tb.write(0, row, fgCyan, "║" & " ".repeat(termWidth - 2) & "║")
    inc row  
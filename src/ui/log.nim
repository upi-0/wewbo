{.deprecated.}
import pkg/illwill
import ./asset
import std/[
  osproc,
  strutils,
  streams,
  os
]

proc show_log_until_complete*(process: Process, message: string, checkup: int = 500): int {.deprecated.} =
  var
    stream = process.outputStream()
    width = terminalWidth()
    height = terminalHeight()
    tb = newTerminalBuffer(width, height)
    logBuffer: seq[string] = @[]
    maxLogLines = height - 11  # Reserve space for border and banner

  proc cleanup() {.noconv.} =
    illwillDeinit()
    showCursor()
    quit(0)

  proc renderFrame() =
    tb.clear()
    tb.renderBanner()
    tb.renderTopBorder(7, title=message)
    
    # Render content area borders
    for i in 8..height - 2:
      tb.write(0, i, fgCyan, "║" & " ".repeat(width - 2) & "║")
    
    tb.renderBottomBorder(width, height - 1)

  proc renderLogs() =
    # Clear content area
    for i in 9..height - 2:
      tb.write(2, i, fgWhite, " ".repeat(width - 4))
    
    # Render visible logs
    var displayRow = 9
    let startIdx = max(0, logBuffer.len - maxLogLines)
    
    for i in startIdx..<logBuffer.len:
      if displayRow >= height - 1:
        break
      
      let line = logBuffer[i]
      let displayLine = if line.len > width - 6:
        line[0..<(width - 6)] & "║"
      else:
        line
      
      tb.write(2, displayRow, fgWhite, displayLine)
      displayRow += 1
    
    tb.display()

  proc addLog(line: string) =
    if line.len > 0:
      # Split multi-line logs
      let lines = line.strip().split('\n')
      for l in lines:
        if l.strip().len > 0:
          logBuffer.add(l.strip())
      
      # Keep buffer size manageable
      if logBuffer.len > 1000:
        logBuffer = logBuffer[logBuffer.len - 500..^1]

  try :
    illwillInit(fullscreen=false)
    setControlCHook(cleanup)
    hideCursor()
  except IllwillError :
    discard    
    
  renderFrame()
  tb.display()

  var outputBuffer = ""
  
  while true:
    if process.running():
      # Read available output without blocking
      try:
        let available = stream.readAll()
        if available.len > 0:
          outputBuffer &= available
          
          # Process complete lines
          let lines = outputBuffer.split('\n')
          for i in 0..<lines.len - 1:
            addLog(lines[i])
          
          # Keep incomplete line in buffer
          outputBuffer = lines[^1]
          
          renderLogs()
      except:
        discard
      
      sleep(checkup)
    else:
      # Process any remaining output
      try:
        let remaining = stream.readAll()
        if remaining.len > 0:
          outputBuffer &= remaining
          let lines = outputBuffer.split('\n')
          for line in lines:
            addLog(line)
          renderLogs()
      except:
        discard
      
      sleep(checkup)  # Give user time to see final output
      return process.peekExitCode()

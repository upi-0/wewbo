# Package

version       = "0.9.3"
author        = "upi-0"
description   = "An interactive terminal application for streaming and downloading anime from various streaming sources."
license       = "GPL-3.0"
srcDir        = "src"
installExt    = @["nim"]
bin           = @["wewbo"]

skipDirs = @["asset"]

# Dependencies

requires "illwill >= 0.4.1"
requires "q >= 0.0.8"
requires "htmlparser"
requires "malebolgia >= 1.3.0"
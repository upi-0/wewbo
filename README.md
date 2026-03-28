# wewbo
An interactive terminal application for searching and watching anime from various streaming sources. [Install Here](#install)
<p align="center">
  <img width="75%" src="https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/asset/tuiPreview.png">
</p>

## About

Wewbo is a command-line-based application that allows you to search for anime, select episodes, and watch them instantly using your favorite media player (MPV or FFplay). The application supports multiple anime sources with an easy-to-use interface.

## Sources Status
| Name | Web | Status | Issue |
|---------|-----------|----| -- |
| Hime  | https://hianime.to | ❌ | End of Service |
| Kura | https://v8.kuramanime.tel | ❌ | Cryptography |
| Pahe | https://animepahe.to | ✅ | - |
| Taku | https://otakudesu.best | ✅ | - |
| Kass | https://kaa.lt | ✅ | - |

## How to Use

### Streaming

```bash
wewbo [anime title]
wewbo stream [anime title]
```

### Downloading
```bash
wewbo dl [anime title]
```
### Usage Examples

```bash
# Search and watch anime from animepahe (default)
wewbo "slow loop"

# Search for anime from otakudesu
wewbo "slow loop:taku"

# Search for anime using FFplay as player
wewbo "attack on titan" -p:ffplay

# Search for anime from otakudesu using external MPV as player
wewbo "demon slayer:taku" --mpv:/path/to/mpv
```

## Install
Make sure [mpv](https://mpv.io) & [ffmpeg](https://www.ffmpeg.org/) are available in your `$PATH`. [Learn how](https://www.google.com/search?q=adding+app+to+path)
### Windows
<b>Scoop</b>
```powershell
# Install Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression

# Install wewbo & mpv
scoop bucket add extras
scoop install mpv https://github.com/upi-0/wewbo/releases/latest/download/wewbo.json

# Install ffmpeg (recommended)
scoop install ffmpeg
```
### Linux

<b>Curl</b>
```bash
curl -fsSL "https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/install.sh" | bash
```

<b>AUR</b>
```bash
yay -S wewbo
```
```bash
paru -S wewbo
```

### Nim
<b>Git Clone</b>
```bash
git clone https://github.com/upi-0/wewbo; cd wewbo
nimble build -y
```
<b>Install directly</b>
```bash
nimble install wewbo
```

## Roadmap

- [x] HTTP Cache (v0.7)
- [x] Batch Downloader (v0.8)
- [x] Concurrently Searching (v0.9)
- [x] Cleaned TUI (v0.9.5)
- [ ] Fix all known bugs (v1)
- [ ] Soft Sub translator (v1.1)
- [ ] Load external extractor lib (v1.2)

---

## For Developers

### Technologies Used

- **q**: parsing HTML using CSS selector
- **htmlparser**: parsing HTML
- **illwill**: TUI design
- **malebolgia**: multiprocessing

## Bantu Service Laptop

https://saweria.co/upi0

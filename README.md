# Wewbo
An interactive terminal application for searching and watching anime from various streaming sources.
<p align="center">
  <img width="75%" src="https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/asset/tuiPreview.png">
</p>

## About

Wewbo is a command-line-based application that allows you to search for anime, select episodes, and watch them instantly using your favorite media player (MPV or FFplay). The application supports multiple anime sources with an easy-to-use interface.

## Install
### Scoop
```bash
scoop install https://raw.github.com/upi-0/wewbo/main/wewbo.json
```
### Nim
```bash
git clone https://github.com/upi-0/wewbo
cd wewbo
nimble install q htmlparser illwill
nim c src/wewbo
```

## Features
- Search anime from various sources (Kuramanime, Animepahe, Hianime, Otakudesu)
- Interactive and easy-to-use terminal interface
- Support for multiple media players (MPV, FFplay)
- HLS stream extraction (HTTP Live Streaming)
- HTTP cache for better performance
- Easy episode navigation
- Download manager for batch downloading

## System Requirements

- Media Player: MPV or FFplay installed on your system
- Internet connection

## How to Use

### Basic Commands

```bash
wewbo [anime title]
```

### Options

- `-s`: Select anime source (default: `kura`)
- `kura` - Kuramanime
- `pahe` - Animepahe
- `hime` - Hianime
- `taku` - Otakudesu

- `-p` or `--player`: Select media player (default: `mpv`)
- `mpv` - MPV Player
- `ffplay` - FFplay

### Usage Examples

```bash
# Search and watch anime from Kuramanime (default)
wewbo "naruto"

# Search for anime from Animepahe
wewbo -s:pahe "one piece"

# Search for anime using FFplay as player
wewbo -p:ffplay "attack on titan"

# Option Combinations
wewbo -s:hime -p:mpv "demon slayer"
```

### How It Works

1. Run the command with the title of the anime you want to search for
2. Select the anime from the search results using the keyboard
3. Select the episode you want to watch
4. The application will automatically open the media player and start streaming

## Performance Information

Average response time by source (in seconds):

- Animepahe: 2.365s
- Kuramanime: 2,942s
- Hianime: 3,516s
- Otakudesu: 5,968s

## Roadmap

- [x] HTTP Cache (v0.7)
- [x] Batch Downloader (v0.8)
- [ ] Concurrently Searching (v0.9)
- [ ] Cleaned TUI (v0.9.5)

---

## For Developers

### Technologies Used

- **Language**: Nim
- **HTTP Client**: Custom HTTP client with cache support
- **Media Processing**: HLS stream extraction
- **UI**: Terminal-based TUI with interactive selection


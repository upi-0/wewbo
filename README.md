# Wewbo
An interactive terminal application for searching and watching anime from various streaming sources. [Install Here](https://github.com/upi-0/wewbo#install)
<p align="center">
  <img width="75%" src="https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/asset/tuiPreview.png">
</p>

## About

Wewbo is a command-line-based application that allows you to search for anime, select episodes, and watch them instantly using your favorite media player (MPV or FFplay). The application supports multiple anime sources with an easy-to-use interface.

## Sources Status
| Name | Web | Status | Issue |
|---------|-----------|----| -- |
| Hime  | https://hianime.to | ✅ | - |
| Kura | https://v8.kuramanime.tel | ❌ | Cryptography |
| Pahe | https://animepahe.to | ✅ | - |
| Taku | https://otakudesu.best | ✅ | - |

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

### Options
```bash
wewbo 0.8
list command: `wewbo [command][opts][narg]`

stream
 -s             Select Source [kura|pahe|hime|taku]
 -p             Select Player [ffmpeg|mpv]

dl
 -s             Select Source [kura|pahe|hime|taku]
 --outdir       Define output directory
 -fps           Set Video frame per second
 -crf           Set Video CRF (For compression)
 --no-sub       Dont include subtitle (Soft-sub only)
```
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


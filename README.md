# Wewbo
An interactive terminal application for searching and watching anime from various streaming sources.
<center>
<img src="https://raw.githubusercontent.com/upi-0/wewbo/refs/heads/main/asset/tuiPreview.png">
</center>

## About

Wewbo is a command-line-based application that allows you to search for anime, select episodes, and watch them instantly using your favorite media player (MPV or FFplay). The application supports multiple anime sources with an easy-to-use interface.

## Features

- Search anime from various sources (Kuramanime, Animepahe, Hianime, Otakudesu)
- Interactive and easy-to-use terminal interface
- Support for multiple media players (MPV, FFplay)
- HLS stream extraction (HTTP Live Streaming)
- HTTP cache for better performance
- Easy episode navigation
- Download manager for batch downloading

## System Requirements

- Windows OS
- Media Player: MPV or FFplay installed on your system
- Internet connection

## How to Use

### Basic Commands

```bash
wewbo [anime title]
```

### Options

- `-n` or `--name`: Select anime source (default: `kura`)
- `kura` - Kuramanime
- `pahe` - Animepahe
- `hian` - Hianime
- `taku` - Otakudesu

- `-p` or `--player`: Select media player (default: `mpv`)
- `mpv` - MPV Player
- `ffplay` - FFplay

### Usage Examples

```bash
# Search and watch anime from Kuramanime (default)
wewbo "naruto"

# Search for anime from Animepahe
wewbo -n:pahe "one piece"

# Search for anime using FFplay as player
wewbo -p:ffplay "attack on titan"

# Option Combinations
wewbo -n:hian -p:mpv "demon slayer"
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
- [ ] Batch Downloader (v0.8)
- [ ] Concurrently Searching (v0.9)
- [ ] Cleaned TUI (v0.9.5)

---

## For Developers

### Technologies Used

- **Language**: Nim
- **HTTP Client**: Custom HTTP client with cache support
- **Media Processing**: HLS stream extraction
- **UI**: Terminal-based TUI with interactive selection

### Project Structure

```
wewbo/
├── src/
│ ├── main.nim # Application entry point
│ ├── options.nim # Parser for command-line arguments
│ ├── process.nim # Process management
│ ├── quick.nim # Quick utilities
│ ├── utils.nim # General utilities
│ │
│ ├── extractor/ # Anime data extraction module
│ │ ├── all.nim # Aggregator of all extractors
│ │ ├── base.nim # Base class for extractor
│ │ ├── types.nim # Data extractor type
│ │ └── extractors/ # Per-source implementation
│ │     ├── animepahe.nim
│ │     ├── hianime.nim
│ │     ├── kuramanime.nim
│ │     └── otakudesu.nim
│ │
│ ├── http/ # HTTP client & utilities
│ │ ├── cache.nim # HTTP cache implementation
│ │ ├── client.nim # HTTP client wrapper
│ │ └── response.nim # HTTP response handler
│ │
│ ├── media/ # Media processing
│ │ ├── download.nim # Download manager
│ │ ├── extractHls.nim # HLS stream extractor
│ │ ├── translate.nim # Media URL translation
│ │ └── types.nim # Media types
│ │
│ ├── player/ # Media player integration
│ │ ├── all.nim # Player aggregator
│ │ ├── base.nim # Base player class
│ │ └── types.nim # Player types
│ │
│ ├── terminal/ # Terminal utilities
│ │ └── paramarg.nim # Argument parser
│ │
│ └── ui/ # User interface
│ ├── ask.nim # Interactive selection
│ ├── asset.nim # UI assets
│ ├── controller.nim # Main UI controller
│ └── log.nim # Logging utilities
│
├── build/ # Build output directory
├── dev/ # Development files
└── README.md
```

### Main Components

#### 1. Extractor System

The extractor system uses an inheritance pattern with the base class `InfoExtractor`:

- **Base Extractor** (`extractor/base.nim`): Provides the base interface for all extractors
- **Concrete Extractors** (`extractor/extractors/`): Specific implementations for each anime source
- **Types** (`extractor/types.nim`): Data types for `AnimeData`, `EpisodeData`, and `ExFormatData`

#### 2. HTTP Layer

- **Client** (`http/client.nim`): Wrapper for HTTP requests
- **Cache** (`http/cache.nim`): Caching implementation to reduce redundant requests
- **Response** (`http/response.nim`): Handler for HTTP responses

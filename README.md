# claude-code-jarvis

JARVIS-style voice notification system for [Claude Code](https://docs.anthropic.com/en/docs/claude-code).

Claude Code の応答をJARVIS風デジタル音声で自動読み上げする Stop Hook システム。  
[VOICEVOX](https://voicevox.hiroshiba.jp/) + FFmpeg で、映画のAIアシスタントのような音声体験を実現します。

https://github.com/user-attachments/assets/placeholder-demo-video

## Features

- **JARVIS-style digital voice** - VOICEVOX + FFmpeg audio effects (highpass/lowpass, echo, phaser, chorus, EQ)
- **Windows Toast notifications** - BurntToast module for visual notifications alongside voice
- **Beep fallback** - Graceful degradation when VOICEVOX is unavailable
- **VOICEVOX dictionary management** - Bulk registration of tech terms for correct pronunciation
- **Cooldown & mutex** - Prevents overlapping playback
- **Auto-start VOICEVOX** - Automatically launches VOICEVOX if not running
- **Parameter tuning** - Interactive mode to fine-tune voice parameters

## Architecture

```
Claude Code (Stop Hook)
├── speak_jarvis.ps1      # Voice synthesis & playback
│   ├── VOICEVOX API      # Japanese TTS engine (localhost:50021)
│   └── FFmpeg             # Audio effects pipeline
├── notify_toast.ps1      # Windows Toast notification
└── beep.ps1              # Fallback beep (if VOICEVOX unavailable)
```

### Audio Effects Pipeline

```
VOICEVOX synthesis → adelay (250ms intro)
  → highpass (220Hz) → lowpass (4000Hz)       # Communication-style band limiting
  → aecho (3-tap reverb: 15/25/40ms)          # Spatial depth
  → aphaser (decay=0.10, subtle)              # Electronic shimmer
  → chorus (0.02, minimal)                    # Synthetic thickness
  → EQ: 1200Hz +2dB / 3200Hz +1.5dB          # Mid presence + digital clarity
  → volume (1.6x) → apad (0.3s tail)         # Final gain + tail padding
```

## Requirements

| Software | Version | Required |
|----------|---------|----------|
| **Windows** | 10/11 | Yes |
| **PowerShell** | 5.1+ | Yes |
| **[VOICEVOX](https://voicevox.hiroshiba.jp/)** | Latest | Yes |
| **[FFmpeg](https://ffmpeg.org/)** | Latest | Recommended |
| **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** | Latest | Yes |
| **[BurntToast](https://github.com/Windos/BurntToast)** | Latest | Optional (for toast notifications) |

### Install dependencies

```powershell
# FFmpeg (via winget)
winget install Gyan.FFmpeg

# BurntToast (for toast notifications)
Install-Module -Name BurntToast -Force
```

## Quick Start

### 1. Clone the repository

```powershell
git clone https://github.com/YOUR_USERNAME/claude-code-jarvis.git
cd claude-code-jarvis
```

### 2. Test VOICEVOX connection

Launch VOICEVOX, then run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test_jarvis.ps1
```

### 3. Configure Claude Code hooks

Add the following to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\path\\to\\claude-code-jarvis\\speak_jarvis.ps1\"",
            "timeout": 30000
          },
          {
            "type": "command",
            "command": "powershell -NoProfile -ExecutionPolicy Bypass -File \"C:\\path\\to\\claude-code-jarvis\\notify_toast.ps1\"",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

Replace `C:\\path\\to\\claude-code-jarvis` with the actual path where you cloned this repository.

### 4. Register tech term dictionary (recommended)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action BulkRegister
```

This registers ~65 tech terms (React, TypeScript, GitHub, etc.) with correct Japanese pronunciation.

## Configuration

### speak_jarvis.ps1 parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-SpeakerId` | 21 | VOICEVOX speaker ID (21 = Kenzaki Mesuo Normal) |
| `-SpeedScale` | 1.0 | Speech speed (0.5-2.0) |
| `-PitchScale` | 0.06 | Pitch adjustment (-0.15 to 0.15) |
| `-IntonationScale` | 0.8 | Intonation intensity (0.0-2.0) |
| `-VolumeScale` | 1.4 | Volume (0.0-2.0) |
| `-MaxLength` | 250 | Max characters to read aloud |
| `-CooldownSeconds` | 5 | Minimum interval between playbacks |
| `-Debug` | false | Enable debug logging to `$TEMP/jarvis_debug.log` |

### Voice tuning

Use interactive tuning mode to find your ideal voice:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test_jarvis.ps1 -Tune
```

List all available VOICEVOX speakers:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File test_jarvis.ps1 -ListSpeakers
```

## Dictionary Management

The dictionary system ensures tech terms are pronounced correctly by VOICEVOX.

### Quick commands

```powershell
# Bulk register starter dictionary (~65 terms)
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action BulkRegister

# Register a single word
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action Register -Surface "Vercel" -Pronunciation "バーセル" -AccentType 1

# List all registered words
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action List

# Search
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action Search -Surface "Git"

# Test pronunciation
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action Test -Surface "Supabase"

# Backup
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action Backup

# Restore from backup
powershell -NoProfile -ExecutionPolicy Bypass -File dict/voicevox-dict-helper.ps1 -Action Restore -BackupFile "path/to/backup.json"
```

### Starter dictionary contents

The built-in dictionary covers:

- **Languages & Frameworks**: TypeScript, React, Next.js, Vue, Svelte, Tailwind, Prisma, etc.
- **Platforms**: GitHub, Vercel, Supabase, Docker, Kubernetes, Stripe, etc.
- **Tools**: ESLint, Webpack, FFmpeg, Playwright, shadcn, etc.
- **Acronyms**: API, CLI, CI/CD, PR, SSE, JWT, npm, LLM, etc.
- **AI**: Claude, Anthropic, VOICEVOX, JARVIS, etc.

You can add your own project-specific terms using the `Register` action.

## How It Works

1. **Claude Code finishes a response** → Stop Hook triggers
2. **speak_jarvis.ps1** receives the assistant's last message via stdin (JSON)
3. **Markdown is stripped** (code blocks, URLs, formatting removed)
4. **Text is truncated** to `MaxLength` characters at a sentence boundary
5. **VOICEVOX synthesizes** the cleaned text to WAV
6. **Vowel shortening** applied for natural-sounding speech (final mora 80%, long vowels 93%)
7. **Interrogative pitch boost** for question sentences
8. **FFmpeg applies** the JARVIS digital effects chain
9. **Background playback** via ffplay (or winmm.dll fallback)
10. **notify_toast.ps1** shows a Windows notification in parallel

## File Structure

```
claude-code-jarvis/
├── speak_jarvis.ps1              # Main: JARVIS voice synthesis + playback
├── notify_toast.ps1              # Toast notification (BurntToast)
├── beep.ps1                      # Fallback beep notification
├── test_jarvis.ps1               # Test suite + interactive tuning
├── dict/
│   ├── voicevox-dict-helper.ps1  # Full dictionary management tool
│   └── voicevox-dict-register.ps1 # Quick batch registration
├── examples/
│   └── settings.json             # Claude Code hook configuration example
├── LICENSE
└── README.md
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| No sound | Check VOICEVOX is running (`http://127.0.0.1:50021/version`) |
| Robotic/unnatural voice | Run `test_jarvis.ps1 -Tune` to adjust parameters |
| FFmpeg not found | Install via `winget install Gyan.FFmpeg`, restart terminal |
| Overlapping audio | Increase `-CooldownSeconds` parameter |
| Wrong pronunciation | Register the term with `dict/voicevox-dict-helper.ps1 -Action Register` |
| Toast not showing | Install BurntToast: `Install-Module -Name BurntToast -Force` |
| Debug info needed | Add `-Debug` flag to `speak_jarvis.ps1`, check `$TEMP/jarvis_debug.log` |

## Credits

- **[VOICEVOX](https://voicevox.hiroshiba.jp/)** - Open-source Japanese text-to-speech engine by Hiroshiba
- **[FFmpeg](https://ffmpeg.org/)** - Audio/video processing
- **[Claude Code](https://docs.anthropic.com/en/docs/claude-code)** - Anthropic's CLI for Claude
- **[BurntToast](https://github.com/Windos/BurntToast)** - Windows Toast notification module

## License

MIT License - see [LICENSE](LICENSE) for details.

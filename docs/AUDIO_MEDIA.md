# Audio and Media

How audio control and media player integration work in iNiR.

## Audio

### PipeWire integration

iNiR controls audio through PipeWire via the Quickshell PipeWire module and `wpctl` (WirePlumber's CLI). This means it works with PipeWire out of the box, no PulseAudio compatibility layer needed.

### Volume control

Keybinds and OSD handle the basics:

| Key | Action |
|-----|--------|
| Volume Up / Down | Adjust default sink volume |
| Mute | Toggle default sink mute |
| Mic Mute | Toggle default source mute |

The OSD (on-screen display) appears for volume and brightness changes, showing the current level with an animated bar.

### Per-app mixer

The right sidebar (ii) and action center (waffle) include a per-app volume mixer. Each app that's outputting audio appears with its own volume slider. You can mute individual apps or adjust their volume independently.

### EasyEffects

If EasyEffects is installed, iNiR detects its virtual sink and controls the physical sink behind it instead. This means volume control works correctly whether EasyEffects is running or not. A toggle in the right sidebar/action center lets you enable/disable EasyEffects.

The Equalizer Phase 1 capability is disabled by default and is separate from normal Media playback. EasyEffects is its first optional backend, while `socat` is used only as an optional transport to the local EasyEffects control socket. If either the backend or transport is unavailable, the Equalizer capability remains unavailable and playback continues normally.

Native EasyEffects and Flatpak installations can be detected at runtime. Package-managed installs therefore do not need to hard-depend on EasyEffects or `socat`; users who want the Equalizer controls can install or opt into those components separately.

### IPC

```bash
inir audio volumeUp         # Increase volume
inir audio volumeDown       # Decrease volume
inir audio mute             # Toggle output mute
inir audio micMute          # Toggle mic mute
```

## Media players

### MPRIS support

iNiR picks up any MPRIS-compatible media player automatically. Spotify, Firefox, mpv, VLC, Celluloid, Amberol, whatever speaks MPRIS shows up in the media controls.

The media player widget appears in:
- The bar (compact now-playing indicator)
- Media controls popup (`iiMediaControls`)
- Right sidebar
- Waffle action center

### MPD and rmpc

`rmpc` is an MPD client; neither it nor MPD exposes MPRIS by itself. Hadalis therefore keeps Media on its normal MPRIS boundary and uses `mpd-mpris` as the bridge. Arch audio/full-experience packages include `mpd-mpris`; existing repo-managed Arch installs receive it through required migration `042-mpd-mpris-bridge` on `inir update`/migration. Its default user service connects to MPD on `localhost:6600`.

Hadalis probes for a local MPD process and the `mpd-mpris` binary at startup, and also watches PipeWire for an MPD output stream. If MPD is present but no `org.mpris.MediaPlayer2.mpd` player exists, it starts `mpd-mpris.service`. This covers both PipeWire-backed MPD and direct-ALSA output. The bridge then appears through the same Quickshell MPRIS service as every other player, so the Bar, Media popup and Sidebars need no MPD-specific UI path. If the bridge package/service is unavailable, MPD playback continues normally and only Hadalis Media integration stays unavailable.

For a non-default MPD host, port, password, or Unix socket, configure the `mpd-mpris` user service for that MPD instance. NixOS/Home Manager users should enable their `services.mpd-mpris` module rather than expecting Hadalis to create a system service.

### Player prioritization

When multiple players are active, iNiR picks the most relevant one:

1. A player that's currently playing beats one that's paused
2. The user's manually selected ("tracked") player beats auto-detection
3. If nothing is playing, the last active player stays visible

### Local Music

The left sidebar Music tab is local-only. Choose a library folder (the XDG Music directory is the default) and Hadalis recursively indexes common audio formats. It reads tags and duration when the optional Python `mutagen` module is present, otherwise it falls back to filenames and folder names. Common cover-image names such as `cover`, `folder`, `front`, `album` and `artwork` are picked up from each track folder.

The player discovers `.m3u`/`.m3u8` playlists and also exposes folders containing multiple tracks as playable collections. Songs, playlists and the active queue are selectable directly in the sidebar. Playback, seek, next/previous, shuffle, repeat and volume are driven through mpv's local Unix-socket IPC; no YouTube session, browser cookies, yt-dlp or network music API is needed.

The historical `YtMusic` source remains only as compatibility code for now and is no longer routed from the Left Sidebar or its Settings UI.

### Media controls layouts

The media controls popup has multiple layout presets you can choose from in Settings. Different presets show different arrangements of album art, controls, and track info.

## SongRec (music recognition)

If SongRec is installed, you can trigger music recognition from the shell. It listens to your audio output, identifies the song (Shazam-style), and shows the result. Useful when you hear something playing and want to know what it is.

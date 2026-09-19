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

Hadalis probes for the `mpd-mpris` binary and watches the MPD/PipeWire session. For the normal local endpoint (`localhost/127.0.0.1:6600`) it starts the distro-provided `mpd-mpris.service` when needed. If Left Sidebar Music is configured for another host, port, or Unix socket, Hadalis launches a shell-owned `mpd-mpris` instance named `org.mpris.MediaPlayer2.mpd.hadalis` with that exact endpoint instead of reusing an unrelated default bridge. The bridge then appears through the same Quickshell MPRIS service as every other player, so the Bar, Media popup and Sidebars observe one playback session. If the bridge binary/service is unavailable, MPD protocol playback remains usable and only MPRIS-wide shell integration is reduced.

NixOS/Home Manager users can still manage their normal MPD/MPRIS services through `services.mpd-mpris`; Hadalis does not overwrite those unit definitions.

### Player prioritization

When multiple players are active, iNiR picks the most relevant one:

1. A player that's currently playing beats one that's paused
2. The user's manually selected ("tracked") player beats auto-detection
3. If nothing is playing, the last active player stays visible

### Local Music

The left sidebar **Music** tab is a frontend for the user's MPD library. MPD owns the database, saved playlists and active queue; Hadalis does not create a second player process. The default endpoint is `127.0.0.1:6600`, configurable in Settings. The optional local folder field is only a path override for resolving cover files when MPD cannot report `music_directory`.

Songs come from MPD `listallinfo`; saved MPD playlists, folder collections and the live MPD queue are selectable directly in the sidebar. Double-clicking a song appends that database URI to the existing MPD queue with `addid` and immediately starts the exact appended entry with `playid`, so existing queued tracks are preserved. Queue rows can be removed individually through MPD `deleteid`, and the Queue view exposes a Clear action backed by MPD `clear`. Starting a collection still replaces the MPD queue with that collection. Database refresh calls MPD `update`.

Normal transport integration uses the endpoint-matched `mpd-mpris` bridge: play/pause, previous/next, seeking, volume and shuffle prefer the MPD MPRIS player exposed through `MprisController`. Direct MPD commands are only a graceful fallback or are used for MPD-only operations such as queue replacement/database update. Bar, Media Popup and other media surfaces therefore observe the same session.

The sidebar now-playing surface reuses the same `PlayerControl` component as the Bar Media popup, including the shared artwork, progress, transport controls and CAVA presentation. Songs, Playlists and Queue are explicit scrollable views; Songs/Queue use compact 50 px rows, the Queue has per-track remove plus Clear controls, and the Songs search field is height-capped so it cannot consume the library viewport. Song rows resolve folder covers first; when no local cover file exists, the MPD helper reads `albumart` (then `readpicture` for embedded art), caches one image per album/folder under the user cache directory, and exposes it to QML as a `file://` URL.

The **Lyrics** tab is local-only. For the current MPD track, Hadalis looks beside the resolved audio path for same-name `.lrc` (preferred) or `.txt` sidecars. Timed LRC lines follow MPRIS/MPD playback position; unsynchronized text remains manually scrollable. This tab performs no network lyric lookup.

The historical `YtMusic` source remains only as compatibility code and is no longer routed from the Left Sidebar or its Settings UI.

### Media controls layouts

The media controls popup has multiple layout presets you can choose from in Settings. Different presets show different arrangements of album art, controls, and track info.

## SongRec (music recognition)

If SongRec is installed, you can trigger music recognition from the shell. It listens to your audio output, identifies the song (Shazam-style), and shows the result. Useful when you hear something playing and want to know what it is.

use std::collections::{BTreeMap, HashMap};
use std::fs;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use anyhow::{anyhow, bail, Context, Result};
use clap::Parser;
use serde::Deserialize;
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};

const ART_NAMES: &[&str] = &["cover", "folder", "front", "album", "artwork"];
const ART_EXTENSIONS: &[&str] = &[".jpg", ".jpeg", ".png", ".webp", ".avif"];
const IDLE_SUBSYSTEMS: &[&str] = &[
    "player",
    "playlist",
    "mixer",
    "options",
    "database",
    "stored_playlist",
];

trait ReadWrite: Read + Write {}
impl<T: Read + Write> ReadWrite for T {}

#[derive(Debug, Parser)]
#[command(about = "Dormant persistent MPD backend for Hadalis")]
struct Args {
    #[arg(long, default_value = "127.0.0.1")]
    host: String,

    #[arg(long, default_value_t = 6600)]
    port: u16,

    #[arg(long)]
    music_root: Option<String>,

    #[arg(long)]
    socket: Option<PathBuf>,
}

struct MpdClient {
    stream: BufReader<Box<dyn ReadWrite + Send>>,
}

impl MpdClient {
    fn connect(host: &str, port: u16) -> Result<Self> {
        Self::connect_with_timeout(host, port, Some(Duration::from_secs(5)))
    }

    fn connect_idle(host: &str, port: u16) -> Result<Self> {
        Self::connect_with_timeout(host, port, None)
    }

    fn connect_with_timeout(
        host: &str,
        port: u16,
        read_timeout: Option<Duration>,
    ) -> Result<Self> {
        let stream: Box<dyn ReadWrite + Send> = if host.starts_with('/') {
            let stream = UnixStream::connect(host)
                .with_context(|| format!("connect MPD unix socket {host}"))?;
            stream.set_read_timeout(read_timeout)?;
            stream.set_write_timeout(Some(Duration::from_secs(5)))?;
            Box::new(stream)
        } else {
            let stream = TcpStream::connect((host, port))
                .with_context(|| format!("connect MPD {host}:{port}"))?;
            stream.set_read_timeout(read_timeout)?;
            stream.set_write_timeout(Some(Duration::from_secs(5)))?;
            let _ = stream.set_nodelay(true);
            Box::new(stream)
        };

        let mut client = Self {
            stream: BufReader::new(stream),
        };
        let greeting = client.read_line()?;
        if !greeting.starts_with("OK MPD ") {
            bail!("invalid_greeting");
        }
        Ok(client)
    }

    fn read_line(&mut self) -> Result<String> {
        let mut line = String::new();
        let bytes = self.stream.read_line(&mut line)?;
        if bytes == 0 {
            bail!("connection_closed");
        }
        Ok(line.trim_end_matches(['\r', '\n']).to_owned())
    }

    fn send_line(&mut self, line: &str) -> Result<()> {
        let inner = self.stream.get_mut();
        inner.write_all(line.as_bytes())?;
        inner.write_all(b"\n")?;
        inner.flush()?;
        Ok(())
    }

    fn command<I, S>(&mut self, name: &str, args: I) -> Result<Vec<String>>
    where
        I: IntoIterator<Item = S>,
        S: AsRef<str>,
    {
        let mut line = name.to_owned();
        for arg in args {
            line.push(' ');
            line.push_str(&quote(arg.as_ref()));
        }
        self.send_line(&line)?;

        let mut result = Vec::new();
        loop {
            let text = self.read_line()?;
            if text == "OK" {
                return Ok(result);
            }
            if text.starts_with("ACK ") {
                bail!("{text}");
            }
            result.push(text);
        }
    }

    fn binary(&mut self, name: &str, uri: &str) -> Result<Option<(Vec<u8>, String)>> {
        let mut data = Vec::new();
        let mut mime = String::new();
        let mut offset = 0usize;

        loop {
            self.send_line(&format!(
                "{name} {} {}",
                quote(uri),
                quote(&offset.to_string())
            ))?;
            let mut total_size = None;
            let mut chunk_size = 0usize;

            loop {
                let text = self.read_line()?;
                if text.starts_with("ACK ") {
                    if offset == 0 {
                        return Ok(None);
                    }
                    bail!("{text}");
                }
                if text == "OK" {
                    break;
                }
                let Some((key, value)) = text.split_once(": ") else {
                    continue;
                };
                match key.to_ascii_lowercase().as_str() {
                    "size" => total_size = value.parse::<usize>().ok(),
                    "type" => mime = value.trim().to_owned(),
                    "binary" => {
                        chunk_size = value
                            .parse::<usize>()
                            .context("invalid_binary_size")?;
                        if chunk_size > 0 {
                            let start = data.len();
                            data.resize(start + chunk_size, 0);
                            self.stream.read_exact(&mut data[start..])?;
                            let mut newline = [0u8; 1];
                            self.stream.read_exact(&mut newline)?;
                            if newline != [b'\n'] {
                                bail!("invalid_binary_terminator");
                            }
                        }
                    }
                    _ => {}
                }
            }

            if chunk_size == 0 || total_size.is_none_or(|size| data.len() >= size) {
                break;
            }
            offset = data.len();
        }

        if data.is_empty() {
            Ok(None)
        } else {
            Ok(Some((data, mime)))
        }
    }
}

struct MpdManager {
    host: String,
    port: u16,
    music_root_override: String,
    client: Mutex<Option<MpdClient>>,
}

impl MpdManager {
    fn new(host: String, port: u16, music_root_override: String) -> Self {
        Self {
            host,
            port,
            music_root_override,
            client: Mutex::new(None),
        }
    }

    fn with_client<T>(
        &self,
        operation: impl FnOnce(&mut MpdClient, &str) -> Result<T>,
    ) -> Result<T> {
        let mut guard = self
            .client
            .lock()
            .map_err(|_| anyhow!("mpd_mutex_poisoned"))?;
        if guard.is_none() {
            *guard = Some(MpdClient::connect(&self.host, self.port)?);
        }

        let result = operation(
            guard.as_mut().expect("client initialized"),
            &self.music_root_override,
        );
        if result.is_err() {
            *guard = None;
        }
        result
    }
}

#[derive(Debug, Deserialize)]
struct Request {
    #[serde(default)]
    id: Value,
    op: String,
    #[serde(default)]
    params: Value,
}

type Record = BTreeMap<String, Vec<String>>;

fn quote(value: &str) -> String {
    format!(
        "\"{}\"",
        value.replace('\\', "\\\\").replace('"', "\\\"")
    )
}

fn pairs(lines: &[String]) -> BTreeMap<String, String> {
    let mut result = BTreeMap::new();
    for line in lines {
        if let Some((key, value)) = line.split_once(": ") {
            result.insert(key.to_ascii_lowercase(), value.to_owned());
        }
    }
    result
}

fn records(lines: &[String], marker: &str) -> Vec<Record> {
    let marker = marker.to_ascii_lowercase();
    let mut result = Vec::new();
    let mut current: Option<Record> = None;

    for line in lines {
        let Some((key, value)) = line.split_once(": ") else {
            continue;
        };
        let key = key.to_ascii_lowercase();
        if key == marker {
            if let Some(previous) = current.take() {
                result.push(previous);
            }
            let mut record = Record::new();
            record.insert(marker.clone(), vec![value.to_owned()]);
            current = Some(record);
        } else if let Some(record) = current.as_mut() {
            record.entry(key).or_default().push(value.to_owned());
        }
    }

    if let Some(record) = current {
        result.push(record);
    }
    result
}

fn first(record: &Record, keys: &[&str]) -> String {
    for key in keys {
        if let Some(value) = record
            .get(&key.to_ascii_lowercase())
            .and_then(|values| values.first())
        {
            let value = value.trim();
            if !value.is_empty() {
                return value.to_owned();
            }
        }
    }
    String::new()
}

fn number(value: &str) -> f64 {
    value
        .split(':')
        .next()
        .and_then(|part| part.parse().ok())
        .unwrap_or(0.0)
}

fn int_prefix(value: &str) -> i64 {
    value
        .split('/')
        .next()
        .and_then(|part| part.parse().ok())
        .unwrap_or(0)
}

fn home_dir() -> PathBuf {
    std::env::var_os("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/"))
}

fn expand_home(value: &str) -> PathBuf {
    if value == "~" {
        return home_dir();
    }
    if let Some(rest) = value.strip_prefix("~/") {
        return home_dir().join(rest);
    }
    PathBuf::from(value)
}

fn cache_dir() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home_dir().join(".cache"))
        .join("hadalis")
        .join("music-covers")
}

fn local_path(uri: &str, music_root: &str) -> String {
    if uri.contains("://") {
        return uri.to_owned();
    }
    let candidate = expand_home(uri);
    if candidate.is_absolute() {
        return candidate.to_string_lossy().into_owned();
    }
    if !music_root.is_empty() {
        return expand_home(music_root)
            .join(candidate)
            .to_string_lossy()
            .into_owned();
    }
    uri.to_owned()
}

fn file_url(path: &Path) -> String {
    let path = if path.is_absolute() {
        path.to_path_buf()
    } else {
        std::env::current_dir()
            .unwrap_or_else(|_| PathBuf::from("/"))
            .join(path)
    };

    let mut output = String::from("file://");
    for byte in path.as_os_str().as_bytes() {
        match *byte {
            b'A'..=b'Z'
            | b'a'..=b'z'
            | b'0'..=b'9'
            | b'/'
            | b'-'
            | b'.'
            | b'_'
            | b'~' => output.push(*byte as char),
            value => output.push_str(&format!("%{value:02X}")),
        }
    }
    output
}

fn folder_art(path_text: &str) -> String {
    if path_text.is_empty() || path_text.contains("://") {
        return String::new();
    }
    let directory = Path::new(path_text)
        .parent()
        .unwrap_or_else(|| Path::new("."));
    let Ok(entries) = fs::read_dir(directory) else {
        return String::new();
    };

    let mut by_name = HashMap::new();
    for entry in entries.flatten() {
        let path = entry.path();
        if path.is_file()
            && let Some(name) = path.file_name().and_then(|name| name.to_str())
        {
            by_name.insert(name.to_ascii_lowercase(), path);
        }
    }

    for base in ART_NAMES {
        for extension in ART_EXTENSIONS {
            if let Some(path) = by_name.get(&format!("{base}{extension}")) {
                return file_url(path);
            }
        }
    }
    String::new()
}

fn track_value(track: &Map<String, Value>, key: &str) -> String {
    track
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or_default()
        .trim()
        .to_owned()
}

fn art_cache_key(track: &Map<String, Value>) -> String {
    let album_artist = {
        let value = track_value(track, "albumArtist");
        if value.is_empty() {
            track_value(track, "artist")
        } else {
            value
        }
    };
    let album = track_value(track, "album");
    let folder = track_value(track, "folder");
    let uri = track_value(track, "uri");

    let identity = if album.is_empty() {
        vec![
            "folder".to_owned(),
            if folder.is_empty() {
                Path::new(&uri)
                    .parent()
                    .unwrap_or_else(|| Path::new(""))
                    .to_string_lossy()
                    .into_owned()
            } else {
                folder
            },
        ]
    } else {
        vec!["album".to_owned(), album_artist, album, folder]
    };

    let mut digest = Sha256::new();
    digest.update(identity.join("\u{001f}").as_bytes());
    format!("{:x}", digest.finalize())
}

fn cached_art(track: &Map<String, Value>) -> String {
    let key = art_cache_key(track);
    let Ok(entries) = fs::read_dir(cache_dir()) else {
        return String::new();
    };
    let mut matches = entries
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(|name| name.starts_with(&format!("{key}.")))
        })
        .collect::<Vec<_>>();
    matches.sort();

    matches
        .into_iter()
        .find(|path| fs::metadata(path).is_ok_and(|meta| meta.len() > 0))
        .map(|path| file_url(&path))
        .unwrap_or_default()
}

fn art_extension(data: &[u8], mime: &str) -> &'static str {
    let mime = mime.to_ascii_lowercase();
    if mime.contains("png") || data.starts_with(b"\x89PNG\r\n\x1a\n") {
        ".png"
    } else if mime.contains("webp")
        || (data.len() >= 12 && &data[..4] == b"RIFF" && &data[8..12] == b"WEBP")
    {
        ".webp"
    } else if mime.contains("gif")
        || data.starts_with(b"GIF87a")
        || data.starts_with(b"GIF89a")
    {
        ".gif"
    } else {
        ".jpg"
    }
}

fn write_cached_art(track: &Map<String, Value>, data: &[u8], mime: &str) -> Result<String> {
    if data.is_empty() {
        return Ok(String::new());
    }
    let cache = cache_dir();
    fs::create_dir_all(&cache)?;
    let target = cache.join(format!(
        "{}{}",
        art_cache_key(track),
        art_extension(data, mime)
    ));
    let temporary = target.with_extension(format!(
        "{}.tmp",
        target
            .extension()
            .and_then(|value| value.to_str())
            .unwrap_or("img")
    ));
    fs::write(&temporary, data)?;
    fs::rename(&temporary, &target)?;
    Ok(file_url(&target))
}

fn build_track(record: &Record, music_root: &str) -> Map<String, Value> {
    let uri = first(record, &["file"]);
    let path = local_path(&uri, music_root);
    let title = {
        let title = first(record, &["title"]);
        if title.is_empty() {
            Path::new(&uri)
                .file_stem()
                .and_then(|value| value.to_str())
                .unwrap_or_default()
                .replace('_', " ")
                .trim()
                .to_owned()
        } else {
            title
        }
    };
    let folder = Path::new(&uri)
        .parent()
        .filter(|path| *path != Path::new("."))
        .map(|path| path.to_string_lossy().into_owned())
        .unwrap_or_default();

    let mut track = Map::new();
    track.insert("uri".into(), json!(uri));
    track.insert("path".into(), json!(path));
    track.insert("title".into(), json!(title));
    track.insert(
        "artist".into(),
        json!(first(record, &["artist", "albumartist"])),
    );
    track.insert("album".into(), json!(first(record, &["album"])));
    track.insert(
        "albumArtist".into(),
        json!(first(record, &["albumartist"])),
    );
    track.insert(
        "duration".into(),
        json!(
            (number(&first(record, &["duration", "time"])) * 1000.0).round() / 1000.0
        ),
    );
    track.insert(
        "track".into(),
        json!(int_prefix(&first(record, &["track"]))),
    );
    track.insert(
        "disc".into(),
        json!(int_prefix(&first(record, &["disc"]))),
    );
    track.insert("genre".into(), json!(first(record, &["genre"])));
    track.insert("date".into(), json!(first(record, &["date"])));
    track.insert("folder".into(), json!(folder));
    track.insert(
        "queueId".into(),
        json!(int_prefix(&first(record, &["id"]))),
    );
    track.insert(
        "queuePos".into(),
        json!(int_prefix(&first(record, &["pos"]))),
    );

    let art = folder_art(&track_value(&track, "path"));
    let art = if art.is_empty() {
        cached_art(&track)
    } else {
        art
    };
    track.insert("art".into(), json!(art));
    track
}

fn music_root(client: &mut MpdClient, override_root: &str) -> String {
    if !override_root.trim().is_empty() {
        return expand_home(override_root).to_string_lossy().into_owned();
    }
    client
        .command("config", std::iter::empty::<&str>())
        .ok()
        .map(|lines| pairs(&lines))
        .and_then(|values| values.get("music_directory").cloned())
        .map(|root| expand_home(&root).to_string_lossy().into_owned())
        .unwrap_or_default()
}

fn status_payload(client: &mut MpdClient, root: &str) -> Result<Value> {
    let status = pairs(&client.command("status", std::iter::empty::<&str>())?);
    let current_records = records(
        &client.command("currentsong", std::iter::empty::<&str>())?,
        "file",
    );
    let queue_records = records(
        &client.command("playlistinfo", std::iter::empty::<&str>())?,
        "file",
    );

    let current = current_records
        .first()
        .map(|record| Value::Object(build_track(record, root)))
        .unwrap_or(Value::Null);
    let queue = queue_records
        .iter()
        .map(|record| Value::Object(build_track(record, root)))
        .collect::<Vec<_>>();

    Ok(json!({
        "connected": true,
        "status": status,
        "current": current,
        "queue": queue,
    }))
}

fn fetch_mpd_art(client: &mut MpdClient, uri: &str) -> Option<(Vec<u8>, String)> {
    for command in ["albumart", "readpicture"] {
        if let Ok(Some(payload)) = client.binary(command, uri)
            && !payload.0.is_empty()
        {
            return Some(payload);
        }
    }
    None
}

fn populate_library_art(client: &mut MpdClient, tracks: &mut [Map<String, Value>]) {
    let mut groups: BTreeMap<String, Vec<usize>> = BTreeMap::new();

    for (index, track) in tracks.iter_mut().enumerate() {
        if !track_value(track, "art").is_empty() {
            continue;
        }
        let cached = cached_art(track);
        if !cached.is_empty() {
            track.insert("art".into(), json!(cached));
            continue;
        }
        groups.entry(art_cache_key(track)).or_default().push(index);
    }

    for indexes in groups.values() {
        let Some(&first_index) = indexes.first() else {
            continue;
        };
        let uri = track_value(&tracks[first_index], "uri");
        let Some((data, mime)) = fetch_mpd_art(client, &uri) else {
            continue;
        };
        let Ok(art) = write_cached_art(&tracks[first_index], &data, &mime) else {
            continue;
        };
        if art.is_empty() {
            continue;
        }
        for index in indexes {
            tracks[*index].insert("art".into(), json!(art));
        }
    }
}

fn snapshot(client: &mut MpdClient, override_root: &str) -> Result<Value> {
    let root = music_root(client, override_root);
    let library_records = records(
        &client.command("listallinfo", std::iter::empty::<&str>())?,
        "file",
    );
    let mut tracks = library_records
        .iter()
        .map(|record| build_track(record, &root))
        .collect::<Vec<_>>();

    tracks.sort_by_key(|track| {
        (
            track_value(track, "artist").to_ascii_lowercase(),
            track_value(track, "album").to_ascii_lowercase(),
            track.get("disc").and_then(Value::as_i64).unwrap_or(0),
            track.get("track").and_then(Value::as_i64).unwrap_or(0),
            track_value(track, "title").to_ascii_lowercase(),
            track_value(track, "uri").to_ascii_lowercase(),
        )
    });
    populate_library_art(client, &mut tracks);

    let playlist_lines = client.command("listplaylists", std::iter::empty::<&str>())?;
    let mut playlist_names = playlist_lines
        .iter()
        .filter_map(|line| {
            let (key, value) = line.split_once(": ")?;
            key.eq_ignore_ascii_case("playlist")
                .then(|| value.to_owned())
        })
        .collect::<Vec<_>>();
    playlist_names.sort_by_key(|name| name.to_ascii_lowercase());

    let mut playlists = Vec::new();
    for name in playlist_names {
        let Ok(lines) = client.command("listplaylistinfo", [&name]) else {
            continue;
        };
        let items = records(&lines, "file")
            .iter()
            .map(|record| Value::Object(build_track(record, &root)))
            .collect::<Vec<_>>();
        playlists.push(json!({
            "id": format!("mpd:{name}"),
            "name": name,
            "kind": "playlist",
            "tracks": items,
        }));
    }

    let mut folders: BTreeMap<String, Vec<Value>> = BTreeMap::new();
    for track in &tracks {
        let folder = track_value(track, "folder");
        if !folder.is_empty() {
            folders
                .entry(folder)
                .or_default()
                .push(Value::Object(track.clone()));
        }
    }
    let folder_values = folders
        .into_iter()
        .filter(|(_, tracks)| tracks.len() >= 2)
        .map(|(folder, tracks)| {
            let name = Path::new(&folder)
                .file_name()
                .and_then(|value| value.to_str())
                .unwrap_or(&folder)
                .to_owned();
            json!({
                "id": format!("folder:{folder}"),
                "name": name,
                "subtitle": folder,
                "kind": "folder",
                "tracks": tracks,
            })
        })
        .collect::<Vec<_>>();

    let mut payload = status_payload(client, &root)?;
    let object = payload
        .as_object_mut()
        .ok_or_else(|| anyhow!("invalid_status_payload"))?;
    object.insert("musicRoot".into(), json!(root));
    object.insert(
        "tracks".into(),
        Value::Array(tracks.into_iter().map(Value::Object).collect()),
    );
    object.insert("playlists".into(), Value::Array(playlists));
    object.insert("folders".into(), Value::Array(folder_values));
    Ok(payload)
}

fn param_string(params: &Value, key: &str) -> Result<String> {
    params
        .get(key)
        .and_then(Value::as_str)
        .map(str::to_owned)
        .ok_or_else(|| anyhow!("missing_{key}"))
}

fn param_strings(params: &Value, key: &str) -> Result<Vec<String>> {
    params
        .get(key)
        .and_then(Value::as_array)
        .ok_or_else(|| anyhow!("missing_{key}"))?
        .iter()
        .map(|value| {
            value
                .as_str()
                .map(str::to_owned)
                .ok_or_else(|| anyhow!("invalid_{key}"))
        })
        .collect()
}

fn playlist_names(client: &mut MpdClient) -> Result<Vec<String>> {
    Ok(client
        .command("listplaylists", std::iter::empty::<&str>())?
        .iter()
        .filter_map(|line| {
            let (key, value) = line.split_once(": ")?;
            key.eq_ignore_ascii_case("playlist")
                .then(|| value.trim().to_owned())
        })
        .filter(|name| !name.is_empty())
        .collect())
}

fn handle_operation(
    client: &mut MpdClient,
    override_root: &str,
    op: &str,
    params: &Value,
) -> Result<Value> {
    match op {
        "status" => {
            let root = music_root(client, override_root);
            let mut payload = status_payload(client, &root)?;
            payload
                .as_object_mut()
                .expect("status payload is object")
                .insert("musicRoot".into(), json!(root));
            Ok(payload)
        }
        "snapshot" => snapshot(client, override_root),
        "queue" => {
            let uris = param_strings(params, "uris")?;
            if uris.is_empty() {
                bail!("empty_queue");
            }
            let index = params.get("index").and_then(Value::as_i64).unwrap_or(0);
            client.command("clear", std::iter::empty::<&str>())?;
            for uri in &uris {
                client.command("add", [uri])?;
            }
            let clamped = index.clamp(0, uris.len().saturating_sub(1) as i64);
            client.command("play", [clamped.to_string()])?;
            Ok(json!({"ok": true}))
        }
        "enqueue" => {
            let uri = param_string(params, "uri")?;
            if uri.is_empty() {
                bail!("empty_uri");
            }
            let play_now = params
                .get("playNow")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let response = pairs(&client.command("addid", [&uri])?);
            if play_now {
                if let Some(song_id) = response.get("id") {
                    client.command("playid", [song_id])?;
                } else {
                    let status =
                        pairs(&client.command("status", std::iter::empty::<&str>())?);
                    let queue_len = status
                        .get("playlistlength")
                        .and_then(|value| value.parse::<i64>().ok())
                        .unwrap_or(1);
                    client.command("play", [(queue_len - 1).max(0).to_string()])?;
                }
            }
            let root = music_root(client, override_root);
            let mut payload = status_payload(client, &root)?;
            payload
                .as_object_mut()
                .expect("status payload is object")
                .insert("musicRoot".into(), json!(root));
            Ok(payload)
        }
        "enqueue-many" => {
            for uri in param_strings(params, "uris")? {
                if !uri.trim().is_empty() {
                    client.command("add", [uri])?;
                }
            }
            let root = music_root(client, override_root);
            let mut payload = status_payload(client, &root)?;
            payload
                .as_object_mut()
                .expect("status payload is object")
                .insert("musicRoot".into(), json!(root));
            Ok(payload)
        }
        "playlist-create" | "playlist-add" => {
            let name = param_string(params, "name")?;
            if name.trim().is_empty() || name.contains('\n') || name.contains('\r') {
                bail!("invalid_playlist_name");
            }
            let mut uris = param_strings(params, "uris")?;
            uris.retain(|uri| !uri.trim().is_empty());
            uris.sort();
            uris.dedup();
            if uris.is_empty() {
                bail!("empty_playlist_selection");
            }

            if op == "playlist-create" {
                let folded = name.to_lowercase();
                if playlist_names(client)?
                    .iter()
                    .any(|existing| existing.to_lowercase() == folded)
                {
                    bail!("playlist_exists");
                }
            }

            for uri in uris {
                client.command("playlistadd", [&name, &uri])?;
            }
            Ok(json!({"ok": true}))
        }
        "command" => {
            const ALLOWED: &[&str] = &[
                "next", "previous", "stop", "play", "pause", "seekcur", "setvol",
                "random", "repeat", "single", "update", "delete", "deleteid", "clear",
            ];
            let name = param_string(params, "name")?;
            if !ALLOWED.contains(&name.as_str()) {
                bail!("command_not_allowed");
            }
            let args = params
                .get("args")
                .and_then(Value::as_array)
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .map(|value| match value {
                    Value::String(value) => value,
                    other => other.to_string(),
                })
                .collect::<Vec<_>>();
            let lines = client.command(&name, &args)?;
            Ok(json!({"ok": true, "lines": lines}))
        }
        _ => bail!("unknown_operation"),
    }
}

fn response(id: Value, result: Result<Value>) -> Value {
    match result {
        Ok(result) => json!({"v": 1, "id": id, "ok": true, "result": result}),
        Err(error) => json!({
            "v": 1,
            "id": id,
            "ok": false,
            "error": error.to_string(),
        }),
    }
}

fn write_json_line(stream: &mut UnixStream, value: &Value) -> Result<()> {
    serde_json::to_writer(&mut *stream, value)?;
    stream.write_all(b"\n")?;
    stream.flush()?;
    Ok(())
}

fn handle_client(
    stream: UnixStream,
    manager: Arc<MpdManager>,
    subscribers: Arc<Mutex<Vec<UnixStream>>>,
) -> Result<()> {
    let mut reader = BufReader::new(stream);
    let mut line = String::new();

    while reader.read_line(&mut line)? > 0 {
        let current = std::mem::take(&mut line);
        let request: Request = match serde_json::from_str(current.trim()) {
            Ok(request) => request,
            Err(error) => {
                write_json_line(
                    reader.get_mut(),
                    &json!({
                        "v": 1,
                        "ok": false,
                        "error": format!("invalid_request: {error}")
                    }),
                )?;
                continue;
            }
        };

        if request.op == "subscribe" {
            let subscriber = reader.get_ref().try_clone()?;
            subscribers
                .lock()
                .map_err(|_| anyhow!("subscriber_mutex_poisoned"))?
                .push(subscriber);
            write_json_line(
                reader.get_mut(),
                &json!({
                    "v": 1,
                    "id": request.id,
                    "ok": true,
                    "result": {"subscribed": true}
                }),
            )?;
            return Ok(());
        }

        let id = request.id;
        let result = manager.with_client(|client, root| {
            handle_operation(client, root, &request.op, &request.params)
        });
        write_json_line(reader.get_mut(), &response(id, result))?;
    }
    Ok(())
}

fn broadcast(subscribers: &Arc<Mutex<Vec<UnixStream>>>, value: &Value) {
    let Ok(mut subscribers) = subscribers.lock() else {
        return;
    };
    subscribers.retain_mut(|stream| write_json_line(stream, value).is_ok());
}

fn idle_loop(host: String, port: u16, subscribers: Arc<Mutex<Vec<UnixStream>>>) {
    loop {
        let mut client = match MpdClient::connect_idle(&host, port) {
            Ok(client) => client,
            Err(error) => {
                broadcast(
                    &subscribers,
                    &json!({
                        "v": 1,
                        "type": "connection",
                        "connected": false,
                        "error": error.to_string()
                    }),
                );
                thread::sleep(Duration::from_secs(2));
                continue;
            }
        };

        broadcast(
            &subscribers,
            &json!({"v": 1, "type": "connection", "connected": true}),
        );

        loop {
            match client.command("idle", IDLE_SUBSYSTEMS) {
                Ok(lines) => {
                    let changed = lines
                        .iter()
                        .filter_map(|line| {
                            let (key, value) = line.split_once(": ")?;
                            key.eq_ignore_ascii_case("changed")
                                .then(|| value.to_owned())
                        })
                        .collect::<Vec<_>>();
                    if !changed.is_empty() {
                        broadcast(
                            &subscribers,
                            &json!({
                                "v": 1,
                                "type": "changed",
                                "subsystems": changed
                            }),
                        );
                    }
                }
                Err(error) => {
                    broadcast(
                        &subscribers,
                        &json!({
                            "v": 1,
                            "type": "connection",
                            "connected": false,
                            "error": error.to_string()
                        }),
                    );
                    break;
                }
            }
        }
        thread::sleep(Duration::from_millis(500));
    }
}

fn default_socket_path() -> PathBuf {
    std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("inir")
        .join("mpd.sock")
}

fn prepare_socket(path: &Path) -> Result<UnixListener> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    if path.exists() {
        fs::remove_file(path)
            .with_context(|| format!("remove stale socket {}", path.display()))?;
    }
    UnixListener::bind(path).with_context(|| format!("bind {}", path.display()))
}

fn main() -> Result<()> {
    let args = Args::parse();
    let socket = args.socket.unwrap_or_else(default_socket_path);
    let root = args.music_root.unwrap_or_default();
    let manager = Arc::new(MpdManager::new(args.host.clone(), args.port, root));
    let subscribers = Arc::new(Mutex::new(Vec::new()));

    {
        let host = args.host.clone();
        let subscribers = subscribers.clone();
        let port = args.port;
        thread::spawn(move || idle_loop(host, port, subscribers));
    }

    let listener = prepare_socket(&socket)?;
    for connection in listener.incoming() {
        let stream = match connection {
            Ok(stream) => stream,
            Err(error) => {
                eprintln!("inir-mpdd: accept failed: {error}");
                continue;
            }
        };
        let manager = manager.clone();
        let subscribers = subscribers.clone();
        thread::spawn(move || {
            if let Err(error) = handle_client(stream, manager, subscribers) {
                eprintln!("inir-mpdd: client error: {error:#}");
            }
        });
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::{pairs, quote, records};

    #[test]
    fn quotes_mpd_arguments() {
        assert_eq!(quote("a\\b\"c"), "\"a\\\\b\\\"c\"");
    }

    #[test]
    fn parses_pairs_case_insensitively() {
        let values = pairs(&["State: play".into(), "volume: 50".into()]);
        assert_eq!(values.get("state").map(String::as_str), Some("play"));
        assert_eq!(values.get("volume").map(String::as_str), Some("50"));
    }

    #[test]
    fn splits_record_stream_on_file_marker() {
        let parsed = records(
            &[
                "file: a.flac".into(),
                "Artist: Alpha".into(),
                "file: b.flac".into(),
                "Artist: Beta".into(),
                "Artist: Guest".into(),
            ],
            "file",
        );
        assert_eq!(parsed.len(), 2);
        assert_eq!(parsed[0]["artist"], vec!["Alpha"]);
        assert_eq!(parsed[1]["artist"], vec!["Beta", "Guest"]);
    }
}

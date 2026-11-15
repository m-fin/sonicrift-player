/**
 * The shape native `playlist.add` actually accepts.
 *
 * expo-audio's iOS module declares `AudioSource` as a record whose `uri` is a
 * URL string. `createAudioPlaylist` resolves strings and asset ids before
 * construction, but `add` does not. A bare remote URL, a Metro asset id, an
 * object in place of that string, or a missing asset throws
 * `ExpoModulesJSI.JavaScriptValue.TypeError` from `add` and the release
 * runtime turns that into a fatal exception.
 */
export type PlaylistAudioSource = {
  uri: string;
};

export function playlistAudioSource(value: unknown): PlaylistAudioSource | null {
  if (typeof value === 'string') return sourceFromUriString(value);
  if (!value || typeof value !== 'object') return null;
  return sourceFromUriString((value as { uri?: unknown }).uri);
}

export function sourceForPlayback(
  playback: { kind: string; uri?: unknown; assetKey?: unknown; pageUrl?: unknown },
  bundledUri: (assetKey: string) => unknown,
): PlaylistAudioSource | null {
  if (playback.kind === 'remote') return playlistAudioSource(playback.uri);
  if (playback.kind === 'bundled') {
    if (typeof playback.assetKey !== 'string' || playback.assetKey.length === 0) return null;
    return playlistAudioSource(bundledUri(playback.assetKey));
  }
  return null;
}

/**
 * Adds every source it can. A native rejection for one track is swallowed so
 * the rest of the queue still loads and the JS error does not crash iOS.
 */
export function addPlaylistSources(
  add: (source: PlaylistAudioSource) => void,
  sources: readonly PlaylistAudioSource[],
): number {
  let added = 0;
  for (const source of sources) {
    const safe = playlistAudioSource(source);
    if (!safe) continue;
    try {
      add(safe);
      added += 1;
    } catch {
      // One bad track must not abort the queue.
    }
  }
  return added;
}

export function nowPlayingMetadata(input: {
  title: unknown;
  placeholder: boolean;
  artworkUrl?: unknown;
  fallbackArtworkUrl?: unknown;
}): { title: string; artist: string; albumTitle: string; artworkUrl?: string } {
  const artwork = playlistAudioSource(input.artworkUrl) ?? playlistAudioSource(input.fallbackArtworkUrl);
  const title = typeof input.title === 'string' && input.title.trim() ? input.title : 'sonicrift';
  const metadata: { title: string; artist: string; albumTitle: string; artworkUrl?: string } = {
    title,
    artist: 'sonicrift',
    albumTitle: input.placeholder ? 'placeholder' : 'sonicrift',
  };
  if (artwork) metadata.artworkUrl = artwork.uri;
  return metadata;
}

function sourceFromUriString(value: unknown): PlaylistAudioSource | null {
  if (typeof value !== 'string') return null;
  const uri = value.trim();
  if (!uri || uri.includes('\0') || /\s/.test(uri)) return null;
  // Root-relative paths are how the web bundle addresses packaged files.
  // Native URL conversion also accepts an absolute filesystem path as a string.
  if (uri.startsWith('/')) return { uri };
  try {
    const parsed = new URL(uri);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:' && parsed.protocol !== 'file:') {
      return null;
    }
    return { uri };
  } catch {
    return null;
  }
}

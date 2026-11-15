import { Image } from 'react-native';

import type { Track } from '@/sources/catalog';

import { sourceForPlayback, type PlaylistAudioSource } from './native-source';

const bundled: Record<string, number> = {
  'placeholder-rift-tone': require('../../assets/audio/placeholder-rift-tone.wav'),
  'placeholder-neon-pulse': require('../../assets/audio/placeholder-neon-pulse.wav'),
};

/**
 * Resolves a bundled tone to a URI string. Native playlist.add rejects the
 * Metro asset id itself. A missing registry entry returns null instead of
 * throwing, so one absent file cannot crash launch.
 */
function uriForBundledAsset(assetKey: string): string | null {
  const assetModule = bundled[assetKey] as unknown;
  if (typeof assetModule === 'string') return assetModule;
  if (assetModule && typeof assetModule === 'object') {
    const uri = (assetModule as { uri?: unknown }).uri;
    return typeof uri === 'string' ? uri : null;
  }
  if (typeof assetModule !== 'number') return null;
  try {
    const resolved = Image.resolveAssetSource(assetModule);
    return typeof resolved?.uri === 'string' ? resolved.uri : null;
  } catch {
    return null;
  }
}

export function audioSourceFor(track: Track): PlaylistAudioSource | null {
  return sourceForPlayback(track.playback, uriForBundledAsset);
}

/**
 * Bundled tones and public http(s) streams play in Expo Go and on the web.
 * Widget tracks, and any track whose source is not a native URL string, stay
 * in the official SoundCloud player.
 */
export function canQueueNatively(track: Track): boolean {
  return audioSourceFor(track) != null;
}

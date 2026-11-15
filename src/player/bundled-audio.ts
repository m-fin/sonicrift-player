import type { Track } from '@/sources/catalog';

const bundled: Record<string, number> = {
  'placeholder-rift-tone': require('../../assets/audio/placeholder-rift-tone.wav'),
  'placeholder-neon-pulse': require('../../assets/audio/placeholder-neon-pulse.wav'),
};

export function audioSourceFor(track: Track): number | string | null {
  if (track.playback.kind === 'remote') return track.playback.uri;
  if (track.playback.kind === 'bundled') return bundled[track.playback.assetKey] ?? null;
  return null;
}

/**
 * Bundled tones and public http(s) streams play in Expo Go and on the web.
 * Widget tracks stay in the official SoundCloud player.
 */
export function canQueueNatively(track: Track): boolean {
  if (track.playback.kind === 'bundled') return audioSourceFor(track) != null;
  return track.playback.kind === 'remote';
}

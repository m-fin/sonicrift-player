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

export function canQueueNatively(track: Track, platform: string): boolean {
  if (track.playback.kind === 'bundled') return audioSourceFor(track) != null;
  if (track.playback.kind === 'remote') return platform !== 'web';
  return false;
}

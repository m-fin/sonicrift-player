import { isThirdPartyAudio } from '../domain/policy';
import type { Track } from './catalog';
import type { OEmbedPayload } from './soundcloud';
import snapshot from './soundcloud-snapshot.json' with { type: 'json' };

export type SoundCloudFallback = {
  tracks: Track[];
  profile: OEmbedPayload;
};

export function loadSoundCloudSnapshot(): SoundCloudFallback {
  const tracks = snapshot.tracks
    .filter((track) => !isThirdPartyAudio(track))
    .map(
      (track): Track => ({
        id: `soundcloud:${track.id}`,
        title: track.title,
        artist: 'sonicrift',
        permalink: track.permalink,
        description: track.description,
        artworkUrl: track.artworkUrl,
        releasedAt: track.releasedAt,
        durationMs: track.durationMs,
        sourceId: 'soundcloud-snapshot',
        placeholder: false,
        playback: { kind: 'remote', uri: track.streamUrl },
      }),
    );
  return { tracks, profile: snapshot.profile };
}

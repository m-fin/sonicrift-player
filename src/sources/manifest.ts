export type ManifestEntry = {
  id: string;
  title: string;
  artist: string;
  placeholder: boolean;
  audioUrl?: string;
  soundcloudUrl?: string;
  permalink?: string;
  artworkUrl?: string;
  releasedAt?: string;
  durationMs?: number;
  newDrop?: boolean;
  note?: string;
};

export type ManifestFile = {
  schema: string;
  note?: string;
  tracks: ManifestEntry[];
};

export function parseManifest(value: unknown): ManifestFile {
  if (!value || typeof value !== 'object') {
    throw new Error('Track manifest must be a JSON object.');
  }
  const record = value as Record<string, unknown>;
  if (record.schema !== 'sonicrift.tracks/v1') {
    throw new Error('Track manifest schema must be sonicrift.tracks/v1.');
  }
  if (!Array.isArray(record.tracks)) {
    throw new Error('Track manifest is missing tracks.');
  }
  const tracks = record.tracks.map((entry, index) => {
    if (!entry || typeof entry !== 'object') {
      throw new Error(`Track ${index} is not an object.`);
    }
    const track = entry as Record<string, unknown>;
    if (typeof track.id !== 'string' || typeof track.title !== 'string') {
      throw new Error(`Track ${index} needs an id and a title.`);
    }
    if (typeof track.placeholder !== 'boolean') {
      throw new Error(`Track ${track.id} must set placeholder to true or false.`);
    }
    return {
      id: track.id,
      title: track.title,
      artist: typeof track.artist === 'string' ? track.artist : 'sonicrift',
      placeholder: track.placeholder,
      audioUrl: typeof track.audioUrl === 'string' ? track.audioUrl : undefined,
      soundcloudUrl: typeof track.soundcloudUrl === 'string' ? track.soundcloudUrl : undefined,
      permalink: typeof track.permalink === 'string' ? track.permalink : undefined,
      artworkUrl: typeof track.artworkUrl === 'string' ? track.artworkUrl : undefined,
      releasedAt: typeof track.releasedAt === 'string' ? track.releasedAt : undefined,
      durationMs: typeof track.durationMs === 'number' ? track.durationMs : undefined,
      newDrop: typeof track.newDrop === 'boolean' ? track.newDrop : undefined,
      note: typeof track.note === 'string' ? track.note : undefined,
    } satisfies ManifestEntry;
  });
  return {
    schema: 'sonicrift.tracks/v1',
    note: typeof record.note === 'string' ? record.note : undefined,
    tracks,
  };
}

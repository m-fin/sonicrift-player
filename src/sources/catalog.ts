import { isThirdPartyAudio, selectNewDropIds } from '../domain/policy';
import { parseManifest, type ManifestEntry } from './manifest';
import {
  nextRssPage,
  parseSoundCloudRss,
  readOEmbed,
  rssUrlForSoundCloudUser,
  userIdFromWidgetHtml,
  type OEmbedPayload,
} from './soundcloud';

export type TrackPlayback =
  | { kind: 'remote'; uri: string }
  | { kind: 'bundled'; assetKey: string }
  | { kind: 'widget'; pageUrl: string };

export type Track = {
  id: string;
  title: string;
  artist: string;
  permalink: string;
  description?: string;
  artworkUrl?: string;
  releasedAt?: string;
  durationMs?: number;
  sourceId: string;
  placeholder: boolean;
  playback: TrackPlayback;
};

export type TrackSource = {
  id: string;
  load(): Promise<Track[]>;
};

export type Catalog = {
  tracks: Track[];
  newDropIds: string[];
  profile: OEmbedPayload;
  errors: { sourceId: string; message: string }[];
};

const PROFILE_URL = 'https://soundcloud.com/sonicrift';

export function manifestEntryToTrack(entry: ManifestEntry): Track {
  const playback = playbackFromManifest(entry);
  return {
    id: `manifest:${entry.id}`,
    title: entry.title,
    artist: entry.artist || 'sonicrift',
    permalink: entry.permalink || entry.soundcloudUrl || PROFILE_URL,
    description: entry.note,
    artworkUrl: entry.artworkUrl,
    releasedAt: entry.releasedAt,
    durationMs: entry.durationMs,
    sourceId: 'manifest',
    placeholder: entry.placeholder,
    playback,
  };
}

function playbackFromManifest(entry: ManifestEntry): TrackPlayback {
  if (entry.audioUrl?.startsWith('bundled:')) {
    return { kind: 'bundled', assetKey: entry.audioUrl.slice('bundled:'.length) };
  }
  if (entry.audioUrl?.startsWith('https://') || entry.audioUrl?.startsWith('http://')) {
    return { kind: 'remote', uri: entry.audioUrl };
  }
  if (entry.soundcloudUrl) return { kind: 'widget', pageUrl: entry.soundcloudUrl };
  return { kind: 'widget', pageUrl: entry.permalink || PROFILE_URL };
}

export function mergeTracks(groups: Track[][]): Track[] {
  const seenIds = new Set<string>();
  const seenLinks = new Set<string>();
  const merged: Track[] = [];
  for (const group of groups) {
    for (const track of group) {
      if (seenIds.has(track.id)) continue;
      const link = track.placeholder ? '' : track.permalink;
      if (link && seenLinks.has(link)) continue;
      seenIds.add(track.id);
      if (link) seenLinks.add(link);
      merged.push(track);
    }
  }
  return merged.sort((a, b) => {
    if (a.placeholder !== b.placeholder) return a.placeholder ? 1 : -1;
    const aTime = a.releasedAt ? Date.parse(a.releasedAt) : 0;
    const bTime = b.releasedAt ? Date.parse(b.releasedAt) : 0;
    return bTime - aTime;
  });
}

export async function loadSoundCloudTracks(
  fetchText: (url: string) => Promise<string>,
  profileUrl = PROFILE_URL,
): Promise<{ tracks: Track[]; profile: OEmbedPayload }> {
  const oembedUrl = `https://soundcloud.com/oembed?format=json&url=${encodeURIComponent(profileUrl)}`;
  const profile = readOEmbed(JSON.parse(await fetchText(oembedUrl)) as unknown);
  const userId = userIdFromWidgetHtml(profile.html ?? '');
  if (!userId) {
    throw new Error('SoundCloud oEmbed did not include a user id, so the public RSS feed is unavailable.');
  }
  const tracks: Track[] = [];
  let page: string | null = rssUrlForSoundCloudUser(userId);
  const seenPages = new Set<string>();
  for (let hop = 0; page && hop < 5; hop += 1) {
    if (seenPages.has(page)) break;
    seenPages.add(page);
    const xml = await fetchText(page);
    for (const item of parseSoundCloudRss(xml)) {
      if (isThirdPartyAudio(item)) continue;
      tracks.push({
        id: `soundcloud:${item.id}`,
        title: item.title,
        artist: 'sonicrift',
        permalink: item.permalink,
        description: item.description,
        artworkUrl: item.artworkUrl,
        releasedAt: item.releasedAt,
        durationMs: item.durationMs,
        sourceId: 'soundcloud-rss',
        placeholder: false,
        playback: { kind: 'remote', uri: item.streamUrl },
      });
    }
    page = nextRssPage(xml);
  }
  return { tracks, profile };
}

export function loadManifestTracks(value: unknown): Track[] {
  return parseManifest(value).tracks.map(manifestEntryToTrack);
}

export async function loadCatalog(input: {
  sources: TrackSource[];
  fetchText: (url: string) => Promise<string>;
  profileUrl?: string;
  nowMs: number;
  /** Public metadata used only when the live oEmbed/RSS request fails. */
  soundCloudFallback?: { tracks: Track[]; profile: OEmbedPayload };
}): Promise<Catalog> {
  const errors: Catalog['errors'] = [];
  const groups = await Promise.all(
    input.sources.map(async (source) => {
      try {
        return await source.load();
      } catch (error) {
        errors.push({
          sourceId: source.id,
          message: error instanceof Error ? error.message : 'Unknown source error',
        });
        return [];
      }
    }),
  );
  let profile: OEmbedPayload = { title: 'sonicrift', author_url: input.profileUrl ?? PROFILE_URL };
  try {
    const soundcloud = await loadSoundCloudTracks(input.fetchText, input.profileUrl);
    profile = soundcloud.profile;
    groups.push(soundcloud.tracks);
  } catch (error) {
    if (input.soundCloudFallback) {
      groups.push(input.soundCloudFallback.tracks);
      profile = input.soundCloudFallback.profile;
    }
    errors.push({
      sourceId: 'soundcloud',
      message: error instanceof Error ? error.message : 'SoundCloud is unavailable',
    });
  }
  const tracks = mergeTracks(groups);
  return {
    tracks,
    newDropIds: selectNewDropIds(tracks, input.nowMs),
    profile,
    errors,
  };
}

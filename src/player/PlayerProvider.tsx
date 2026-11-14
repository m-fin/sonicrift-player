import { setAudioModeAsync, createAudioPlaylist, type AudioPlaylist, type AudioPlaylistStatus } from 'expo-audio';
import * as Haptics from 'expo-haptics';
import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Platform, Share } from 'react-native';

import { createQueue, cycleRepeat, playId, previousTarget, removeAt, toggleShuffle, type QueueState, type RepeatMode } from '@/domain/queue';
import sampleManifest from '@/sources/sample-manifest.json';
import { loadCatalog, loadManifestTracks, type Catalog, type Track } from '@/sources/catalog';
import { loadSoundCloudSnapshot } from '@/sources/soundcloud-snapshot';
import { audioSourceFor, canQueueNatively } from '@/player/bundled-audio';

const PROFILE_URL = 'https://soundcloud.com/sonicrift';

const emptyStatus: AudioPlaylistStatus = {
  id: '',
  currentIndex: 0,
  currentTime: 0,
  didJustFinish: false,
  duration: 0,
  isBuffering: false,
  isLoaded: false,
  loop: 'none',
  muted: false,
  playbackRate: 1,
  playing: false,
  trackCount: 0,
  volume: 1,
};

type PlayerContextValue = {
  catalog: Catalog | null;
  loading: boolean;
  queue: QueueState;
  current?: Track;
  widgetTrack?: Track;
  engaged: boolean;
  status: AudioPlaylistStatus;
  togglePlay: () => void;
  playTrack: (id: string) => void;
  next: () => void;
  previous: () => void;
  seek: (seconds: number) => void;
  toggleShuffleMode: () => void;
  cycleRepeatMode: () => void;
  removeFromQueue: (index: number) => void;
  shareTrack: (track: Track) => Promise<void>;
};

const PlayerContext = createContext<PlayerContextValue | null>(null);

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`SoundCloud request failed (${response.status}).`);
  }
  return response.text();
}

function metadataFor(track: Track, artworkUrl?: string) {
  return {
    title: track.placeholder ? track.title : track.title,
    artist: 'sonicrift',
    albumTitle: track.placeholder ? 'placeholder' : 'sonicrift',
    artworkUrl: track.artworkUrl ?? artworkUrl,
  };
}

export function PlayerProvider({ children }: { children: ReactNode }) {
  const playlistRef = useRef<AudioPlaylist | null>(null);
  const [playlistReady, setPlaylistReady] = useState(false);
  const [status, setStatus] = useState<AudioPlaylistStatus>(emptyStatus);
  const [catalog, setCatalog] = useState<Catalog | null>(null);
  const [loading, setLoading] = useState(true);
  const [queue, setQueue] = useState<QueueState>(createQueue([]));
  const [widgetTrack, setWidgetTrack] = useState<Track | undefined>(undefined);
  const [engaged, setEngaged] = useState(false);
  const queueRef = useRef(queue);
  const indexRef = useRef(0);
  const syncedOrder = useRef('');

  queueRef.current = queue;

  const tracks = catalog?.tracks ?? [];
  const byId = useMemo(() => new Map(tracks.map((track) => [track.id, track])), [tracks]);

  const nativeOrder = useMemo(
    () => tracks.filter((track) => canQueueNatively(track, Platform.OS)).map((track) => track.id),
    [tracks],
  );

  useEffect(() => {
    let alive = true;
    const created = createAudioPlaylist({ sources: [], loop: 'none', updateInterval: 250 });
    playlistRef.current = created;
    setPlaylistReady(true);
    const subscription = created.addListener('playlistStatusUpdate', (nextStatus) => {
      if (alive) setStatus(nextStatus);
    });
    void setAudioModeAsync({
      playsInSilentMode: true,
      shouldPlayInBackground: true,
      interruptionMode: 'doNotMix',
    }).catch(() => undefined);
    return () => {
      alive = false;
      subscription.remove();
      created.clearLockScreenControls();
      playlistRef.current = null;
      created.release();
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const sources = [
      {
        id: 'sample-manifest',
        async load() {
          return loadManifestTracks(sampleManifest);
        },
      },
    ];
    const remoteUrl = process.env.EXPO_PUBLIC_TRACK_MANIFEST_URL;
    if (remoteUrl) {
      sources.push({
        id: 'remote-manifest',
        async load() {
          return loadManifestTracks(JSON.parse(await fetchText(remoteUrl)) as unknown);
        },
      });
    }
    loadCatalog({
      sources,
      fetchText:
        Platform.OS === 'web'
          ? async () => {
              throw new Error('Browsers cannot read the SoundCloud RSS feed.');
            }
          : fetchText,
      nowMs: Date.now(),
      profileUrl: PROFILE_URL,
      soundCloudFallback: loadSoundCloudSnapshot(),
    })
      .then((next) => {
        if (!cancelled) setCatalog(next);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        const fallback = loadSoundCloudSnapshot();
        setCatalog({
          tracks: [...fallback.tracks, ...loadManifestTracks(sampleManifest)],
          newDropIds: [],
          profile: fallback.profile,
          errors: [{ sourceId: 'catalog', message: error instanceof Error ? error.message : 'Catalog failed to load.' }],
        });
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    setQueue((current) => {
      const keep = current.order[indexRef.current];
      const nextOrder = nativeOrder;
      if (current.order.join('|') === nextOrder.join('|')) return current;
      const index = keep ? Math.max(0, nextOrder.indexOf(keep)) : 0;
      return { ...current, linearOrder: nextOrder, order: current.shuffle ? current.order.filter((id) => nextOrder.includes(id)) : nextOrder, index };
    });
  }, [nativeOrder]);

  useEffect(() => {
    const playlist = playlistRef.current;
    if (!playlist || !playlistReady) return;
    const signature = queue.order.join('|');
    if (syncedOrder.current === signature) return;
    const wasPlaying = syncedOrder.current !== '' && playlist.playing;
    syncedOrder.current = signature;
    playlist.clear();
    for (const id of queue.order) {
      const track = byId.get(id);
      if (!track) continue;
      const source = audioSourceFor(track);
      if (source != null) playlist.add(source);
    }
    const index = Math.min(queue.index, Math.max(playlist.trackCount - 1, 0));
    if (index > 0) playlist.skipTo(index);
    const track = byId.get(queue.order[index] ?? '');
    if (track) {
      playlist.setActiveForLockScreen(true, metadataFor(track, catalog?.profile.thumbnail_url), {
        showNextTrack: true,
        showPreviousTrack: true,
      });
    }
    playlist.loop = queue.repeat === 'off' ? 'none' : queue.repeat === 'one' ? 'single' : 'all';
    if (wasPlaying) playlist.play();
  }, [byId, catalog?.profile.thumbnail_url, playlistReady, queue.index, queue.order, queue.repeat]);

  useEffect(() => {
    const playlist = playlistRef.current;
    if (!playlist) return;
    playlist.loop = queue.repeat === 'off' ? 'none' : queue.repeat === 'one' ? 'single' : 'all';
  }, [queue.repeat]);

  const displayedIndex = status.trackCount > 0 ? status.currentIndex : queue.index;
  indexRef.current = displayedIndex;
  const current = widgetTrack ?? byId.get(queue.order[displayedIndex] ?? '');

  useEffect(() => {
    const playlist = playlistRef.current;
    const track = byId.get(queue.order[displayedIndex] ?? '');
    if (!playlist || !track || widgetTrack) return;
    playlist.updateLockScreenMetadata(metadataFor(track, catalog?.profile.thumbnail_url));
  }, [byId, catalog?.profile.thumbnail_url, displayedIndex, queue.order, widgetTrack]);

  const value = useMemo<PlayerContextValue>(() => {
    const playlist = () => playlistRef.current;
    const stepRelease = (direction: 1 | -1) => {
      const releases = tracks.filter((track) => !track.placeholder);
      const index = releases.findIndex((track) => track.id === widgetTrack?.id);
      const nextTrack = releases[index + direction];
      if (!nextTrack) return;
      if (!canQueueNatively(nextTrack, Platform.OS)) {
        setWidgetTrack(nextTrack);
        return;
      }
      setWidgetTrack(undefined);
      const nextQueue = playId(queueRef.current, nextTrack.id);
      setQueue(nextQueue);
      const player = playlist();
      if (player && player.trackCount === nextQueue.order.length) {
        player.skipTo(nextQueue.index);
        player.play();
      }
    };

    return {
      catalog,
      loading,
      queue,
      current,
      widgetTrack,
      engaged,
      status,
      togglePlay: () => {
        const player = playlist();
        if (!player) return;
        setEngaged(true);
        if (widgetTrack) return;
        if (player.playing) player.pause();
        else player.play();
        void Haptics.selectionAsync().catch(() => undefined);
      },
      playTrack: (id: string) => {
        const track = byId.get(id);
        const player = playlist();
        if (!track || !player) return;
        setEngaged(true);
        if (!canQueueNatively(track, Platform.OS)) {
          player.pause();
          setWidgetTrack(track);
          return;
        }
        setWidgetTrack(undefined);
        const nextQueue = playId(queueRef.current, id);
        setQueue(nextQueue);
        if (player.trackCount === nextQueue.order.length) {
          player.skipTo(nextQueue.index);
          player.play();
        }
        void Haptics.selectionAsync().catch(() => undefined);
      },
      next: () => {
        if (widgetTrack) {
          stepRelease(1);
          return;
        }
        playlist()?.next();
      },
      previous: () => {
        if (widgetTrack) {
          stepRelease(-1);
          return;
        }
        const player = playlist();
        if (!player) return;
        const target = previousTarget(
          { ...queueRef.current, index: indexRef.current },
          player.currentTime,
        );
        if (target.restart) {
          void player.seekTo(0);
          if (!player.playing) player.play();
          return;
        }
        player.previous();
      },
      seek: (seconds: number) => {
        const player = playlist();
        if (!player || widgetTrack) return;
        void player.seekTo(seconds);
      },
      toggleShuffleMode: () => {
        setQueue((currentQueue) => toggleShuffle({ ...currentQueue, index: indexRef.current }));
        setWidgetTrack(undefined);
      },
      cycleRepeatMode: () => {
        setQueue((currentQueue) => ({ ...currentQueue, repeat: cycleRepeat(currentQueue.repeat) }));
      },
      removeFromQueue: (index: number) => {
        setQueue((currentQueue) => removeAt({ ...currentQueue, index: indexRef.current }, index));
      },
      shareTrack: async (track: Track) => {
        const message = `${track.title} — sonicrift`;
        await Share.share(
          Platform.OS === 'ios'
            ? { title: track.title, message, url: track.permalink }
            : { title: track.title, message: `${message}\n${track.permalink}` },
        );
      },
    };
  }, [byId, catalog, current, engaged, loading, queue, status, tracks, widgetTrack]);

  return <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>;
}

export function usePlayer(): PlayerContextValue {
  const value = useContext(PlayerContext);
  if (!value) throw new Error('usePlayer must be used inside PlayerProvider.');
  return value;
}

export type { RepeatMode };

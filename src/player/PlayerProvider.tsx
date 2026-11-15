import { setAudioModeAsync, createAudioPlaylist, type AudioPlaylist, type AudioPlaylistStatus } from 'expo-audio';
import * as Haptics from 'expo-haptics';
import { createContext, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Platform } from 'react-native';

import { createQueue, cycleRepeat, playId, previousTarget, removeAt, replaceOrder, toggleShuffle, type QueueState, type RepeatMode } from '@/domain/queue';
import { audioSourceFor, canQueueNatively } from '@/player/bundled-audio';
import { addPlaylistSources, nowPlayingMetadata } from '@/player/native-source';
import { bindPlaybackKeys, type PlaybackKeys } from '@/player/keyboard';
import { playlistSyncPlan } from '@/player/playlist-sync';
import { shareTrackLink, type ShareResult } from '@/player/share-track';
import sampleManifest from '@/sources/sample-manifest.json';
import { loadCatalog, loadManifestTracks, type Catalog, type Track } from '@/sources/catalog';
import { loadSoundCloudSnapshot } from '@/sources/soundcloud-snapshot';

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
  streamUnplayable: boolean;
  status: AudioPlaylistStatus;
  togglePlay: () => void;
  playTrack: (id: string) => void;
  next: () => void;
  previous: () => void;
  seek: (seconds: number) => void;
  toggleShuffleMode: () => void;
  cycleRepeatMode: () => void;
  removeFromQueue: (index: number) => void;
  shareTrack: (track: Track) => Promise<ShareResult>;
  openInSoundCloudPlayer: () => void;
};

const PlayerContext = createContext<PlayerContextValue | null>(null);

async function fetchText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`SoundCloud request failed (${response.status}).`);
  }
  return response.text();
}

function sameIds(left: string[], right: string[]): boolean {
  return left.length === right.length && left.every((id, index) => id === right[index]);
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
  const [streamUnplayable, setStreamUnplayable] = useState(false);
  const queueRef = useRef(queue);
  const indexRef = useRef(0);
  const widgetRef = useRef(widgetTrack);
  const syncedOrder = useRef('');
  const playRequest = useRef<string | null>(null);
  const keysRef = useRef<PlaybackKeys>({
    toggle: () => undefined,
    seekBy: () => undefined,
  });

  queueRef.current = queue;
  widgetRef.current = widgetTrack;

  const tracks = catalog?.tracks ?? [];
  const byId = useMemo(() => new Map(tracks.map((track) => [track.id, track])), [tracks]);

  const nativeOrder = useMemo(
    () => tracks.filter((track) => canQueueNatively(track)).map((track) => track.id),
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

  useEffect(() => bindPlaybackKeys(keysRef.current), []);

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
              // SoundCloud only sends a CORS header for one radio origin, so a browser cannot read the RSS feed.
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
      const keep = current.order[indexRef.current] ?? current.order[current.index];
      const next = replaceOrder(current, nativeOrder, keep);
      if (sameIds(next.order, current.order) && sameIds(next.linearOrder, current.linearOrder) && next.index === current.index) {
        return current;
      }
      return next;
    });
  }, [nativeOrder]);

  useEffect(() => {
    const playlist = playlistRef.current;
    if (!playlist || !playlistReady) return;
    const signature = queue.order.join('|');
    const requestedId = playRequest.current;
    const orderChanged = syncedOrder.current !== signature;
    if (!orderChanged && !requestedId) return;

    const wasPlaying = syncedOrder.current !== '' && playlist.playing;
    const plan = playlistSyncPlan({
      order: queue.order,
      index: queue.index,
      repeat: queue.repeat,
      wasPlaying,
      requestedId,
    });

    if (orderChanged) {
      syncedOrder.current = signature;
      playlist.clear();
      const sources = queue.order.flatMap((id) => {
        const track = byId.get(id);
        const source = track ? audioSourceFor(track) : null;
        return source ? [source] : [];
      });
      const added = addPlaylistSources((source) => playlist.add(source), sources);
      const index = Math.min(plan.index, Math.max(added - 1, 0));
      if (added > 0 && index > 0) playlist.skipTo(index);
    } else if (requestedId && plan.index !== playlist.currentIndex) {
      playlist.skipTo(plan.index);
    }

    playlist.loop = plan.loop;
    const track = byId.get(queue.order[plan.index] ?? '');
    if (track) {
      try {
        playlist.setActiveForLockScreen(
          true,
          nowPlayingMetadata({
            title: track.title,
            placeholder: track.placeholder,
            artworkUrl: track.artworkUrl,
            fallbackArtworkUrl: catalog?.profile.thumbnail_url,
          }),
          {
            showNextTrack: true,
            showPreviousTrack: true,
          },
        );
      } catch {
        // Invalid now-playing metadata is a native TypeError. Keep playback alive.
      }
    }
    if (plan.play) playlist.play();
    if (requestedId) playRequest.current = null;
  }, [byId, catalog?.profile.thumbnail_url, playlistReady, queue.index, queue.order, queue.repeat]);

  useEffect(() => {
    const playlist = playlistRef.current;
    if (!playlist) return;
    playlist.loop = queue.repeat === 'off' ? 'none' : queue.repeat === 'one' ? 'single' : 'all';
  }, [queue.repeat]);

  const displayedIndex = status.trackCount > 0 ? status.currentIndex : queue.index;
  indexRef.current = displayedIndex;
  const queuedTrack = byId.get(queue.order[displayedIndex] ?? '');
  const current = widgetTrack ?? queuedTrack;

  useEffect(() => {
    const playlist = playlistRef.current;
    if (!playlist || !queuedTrack || widgetTrack) return;
    try {
      playlist.updateLockScreenMetadata(
        nowPlayingMetadata({
          title: queuedTrack.title,
          placeholder: queuedTrack.placeholder,
          artworkUrl: queuedTrack.artworkUrl,
          fallbackArtworkUrl: catalog?.profile.thumbnail_url,
        }),
      );
    } catch {
      // Invalid now-playing metadata is a native TypeError. Keep playback alive.
    }
  }, [catalog?.profile.thumbnail_url, queuedTrack, widgetTrack]);

  useEffect(() => {
    if (status.playing || status.isLoaded) setStreamUnplayable(false);
  }, [status.isLoaded, status.playing]);

  useEffect(() => {
    if (!engaged || widgetTrack || streamUnplayable) return;
    if (!queuedTrack || queuedTrack.playback.kind !== 'remote') return;
    if (status.playing || status.isLoaded || status.isBuffering) return;
    const timer = setTimeout(() => setStreamUnplayable(true), 8000);
    return () => clearTimeout(timer);
  }, [engaged, queuedTrack, status.isBuffering, status.isLoaded, status.playing, streamUnplayable, widgetTrack]);

  const value = useMemo<PlayerContextValue>(() => {
    const playlist = () => playlistRef.current;
    const startNative = (id: string) => {
      const player = playlist();
      setWidgetTrack(undefined);
      setStreamUnplayable(false);
      const nextQueue = playId(queueRef.current, id);
      setQueue(nextQueue);
      playRequest.current = id;
      const signature = nextQueue.order.join('|');
      if (player && syncedOrder.current === signature && player.trackCount === nextQueue.order.length) {
        if (player.currentIndex !== nextQueue.index) player.skipTo(nextQueue.index);
        player.play();
        playRequest.current = null;
      }
    };
    const stepRelease = (direction: 1 | -1) => {
      const releases = tracks.filter((track) => !track.placeholder);
      const index = releases.findIndex((track) => track.id === widgetTrack?.id);
      const nextTrack = releases[index + direction];
      if (!nextTrack) return;
      if (!canQueueNatively(nextTrack)) {
        setWidgetTrack(nextTrack);
        return;
      }
      startNative(nextTrack.id);
    };

    const api: PlayerContextValue = {
      catalog,
      loading,
      queue,
      current,
      widgetTrack,
      engaged,
      streamUnplayable,
      status,
      togglePlay: () => {
        const player = playlist();
        if (!player || widgetTrack) return;
        setEngaged(true);
        setStreamUnplayable(false);
        if (player.playing) player.pause();
        else player.play();
        void Haptics.selectionAsync().catch(() => undefined);
      },
      playTrack: (id: string) => {
        const track = byId.get(id);
        if (!track) return;
        setEngaged(true);
        if (!canQueueNatively(track)) {
          playlist()?.pause();
          setWidgetTrack(track);
          playRequest.current = null;
          return;
        }
        startNative(id);
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
        if (!player || widgetTrack || !Number.isFinite(seconds)) return;
        const duration = player.duration || 0;
        const next = Math.max(0, duration > 0 ? Math.min(seconds, duration) : seconds);
        void player.seekTo(next);
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
      shareTrack: (track: Track) => shareTrackLink(track),
      openInSoundCloudPlayer: () => {
        const track = widgetRef.current ?? byId.get(queueRef.current.order[indexRef.current] ?? '');
        if (!track || track.placeholder) return;
        playlist()?.pause();
        setWidgetTrack(track);
        setStreamUnplayable(false);
      },
    };
    keysRef.current.toggle = () => api.togglePlay();
    keysRef.current.seekBy = (seconds: number) => api.seek((playlist()?.currentTime ?? 0) + seconds);
    return api;
  }, [byId, catalog, current, engaged, loading, queue, status, streamUnplayable, tracks, widgetTrack]);

  return <PlayerContext.Provider value={value}>{children}</PlayerContext.Provider>;
}

export function usePlayer(): PlayerContextValue {
  const value = useContext(PlayerContext);
  if (!value) throw new Error('usePlayer must be used inside PlayerProvider.');
  return value;
}

export type { RepeatMode };

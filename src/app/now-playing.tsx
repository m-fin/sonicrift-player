import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, useWindowDimensions, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { brand, font, formatClock } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';
import { seekRatio } from '@/player/seek-ratio';
import { SoundCloudWidget } from '@/ui/SoundCloudWidget';
import { Visualizer } from '@/ui/Visualizer';

function seedFrom(value: string): number {
  return value.split('').reduce((sum, char) => sum + char.charCodeAt(0), 0);
}

export default function NowPlayingScreen() {
  const insets = useSafeAreaInsets();
  const { height, width } = useWindowDimensions();
  const { current, widgetTrack, status, streamUnplayable, togglePlay, next, previous, seek, toggleShuffleMode, cycleRepeatMode, queue, shareTrack, openInSoundCloudPlayer } =
    usePlayer();
  const scrubWidth = useRef(1);
  const scrubRef = useRef<{ getBoundingClientRect?: () => { left: number; width: number } } | null>(null);
  const shareTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const [shareNote, setShareNote] = useState<string | null>(null);
  useEffect(
    () => () => {
      if (shareTimer.current) clearTimeout(shareTimer.current);
    },
    [],
  );
  const column = Math.min(width, 480);
  const artSize = Math.max(168, Math.min(column - 40, height - 390));

  if (!current) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + 12 }]}>
        <Text style={styles.empty}>nothing queued yet.</Text>
      </View>
    );
  }

  const duration = status.duration || (current.durationMs ? current.durationMs / 1000 : 0);
  const progress = duration > 0 ? Math.min(1, status.currentTime / duration) : 0;
  const widget = Boolean(widgetTrack);
  const showStreamHelp = streamUnplayable && !widget && !current.placeholder;

  return (
    <View style={[styles.screen, { paddingTop: insets.top + 8, paddingBottom: insets.bottom + 12 }]}>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={styles.top}>
          <Pressable accessibilityRole="button" accessibilityLabel="Close now playing" onPress={() => router.back()} hitSlop={12}>
            <Text style={styles.close}>close</Text>
          </Pressable>
          <Text style={styles.kicker}>{current.placeholder ? 'placeholder' : 'now playing'}</Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Share ${current.title}`}
            onPress={() => {
              void shareTrack(current).then((result) => {
                if (result !== 'copied') return;
                setShareNote('link copied');
                if (shareTimer.current) clearTimeout(shareTimer.current);
                shareTimer.current = setTimeout(() => setShareNote(null), 2000);
              });
            }}
            hitSlop={12}>
            <Text style={styles.close}>{shareNote ?? 'share'}</Text>
          </Pressable>
        </View>

        {widget ? (
          <View style={styles.widgetWrap}>
            <SoundCloudWidget pageUrl={current.permalink} height={Math.max(240, Math.min(380, height * 0.46))} autoplay />
            <Text style={styles.widgetNote}>Official SoundCloud player. This track is not using a private API.</Text>
          </View>
        ) : (
          <View style={styles.artWrap}>
            <Image
              source={current.artworkUrl ? { uri: current.artworkUrl } : require('../../assets/images/icon.png')}
              style={[styles.art, { height: artSize }]}
              accessibilityLabel=""
            />
            <View style={styles.visualizer}>
              <Visualizer playing={status.playing} seed={seedFrom(current.id)} />
            </View>
          </View>
        )}

        <View style={styles.meta}>
          <Text style={styles.title} numberOfLines={2}>
            {current.title}
          </Text>
          <Text style={styles.artist}>sonicrift</Text>
        </View>

        {showStreamHelp ? (
          <View style={styles.help}>
            <Text style={styles.helpCopy}>This stream did not start. The official SoundCloud player can play it instead.</Text>
            <Pressable accessibilityRole="button" accessibilityLabel="Open the SoundCloud player" onPress={openInSoundCloudPlayer}>
              <Text style={styles.helpAction}>open soundcloud</Text>
            </Pressable>
          </View>
        ) : null}

        {widget ? null : (
          <View style={styles.scrubBlock}>
            <Pressable
              accessibilityRole="adjustable"
              accessibilityLabel="Seek"
              accessibilityValue={{ min: 0, max: Math.round(duration), now: Math.round(status.currentTime) }}
              onLayout={(event) => {
                scrubWidth.current = event.nativeEvent.layout.width || 1;
              }}
              onPress={(event) => {
                if (duration <= 0) return;
                const native = event.nativeEvent as { locationX?: number; pageX?: number };
                let locationX: number | undefined;
                try {
                  locationX = native.locationX;
                } catch {
                  locationX = undefined;
                }
                const node = scrubRef.current;
                const rect = node?.getBoundingClientRect?.();
                const originX = rect ? rect.left + (typeof window === 'undefined' ? 0 : window.scrollX) : undefined;
                const ratio = seekRatio({
                  locationX,
                  width: scrubWidth.current,
                  pageX: native.pageX,
                  originX,
                  originWidth: rect?.width,
                });
                if (ratio == null) return;
                seek(ratio * duration);
              }}
              ref={(node) => {
                scrubRef.current = node as typeof scrubRef.current;
              }}
              style={styles.scrub}>
              <View style={[styles.scrubFill, { width: `${progress * 100}%` }]} />
            </Pressable>
            <View style={styles.times}>
              <Text style={styles.time}>{formatClock(status.currentTime)}</Text>
              <Text style={styles.time}>{formatClock(duration)}</Text>
            </View>
          </View>
        )}

        <View style={styles.transport}>
          <Pressable accessibilityRole="button" accessibilityLabel="Previous" onPress={previous} style={styles.side}>
            <Text style={styles.sideLabel}>prev</Text>
          </Pressable>
          {widget ? (
            <View style={styles.playSpacer} />
          ) : (
            <Pressable
              accessibilityRole="button"
              accessibilityLabel={status.playing ? 'Pause' : 'Play'}
              onPress={togglePlay}
              style={styles.play}>
              <Text style={styles.playLabel}>{status.playing ? 'pause' : status.isBuffering ? '…' : 'play'}</Text>
            </Pressable>
          )}
          <Pressable accessibilityRole="button" accessibilityLabel="Next" onPress={next} style={styles.side}>
            <Text style={styles.sideLabel}>next</Text>
          </Pressable>
        </View>

        <View style={styles.modes}>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={queue.shuffle ? 'Turn shuffle off' : 'Turn shuffle on'}
            onPress={toggleShuffleMode}
            style={[styles.mode, queue.shuffle && styles.modeOn]}>
            <Text style={[styles.modeLabel, queue.shuffle && styles.modeLabelOn]}>shuffle</Text>
          </Pressable>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Repeat ${queue.repeat}`}
            onPress={cycleRepeatMode}
            style={[styles.mode, queue.repeat !== 'off' && styles.modeOn]}>
            <Text style={[styles.modeLabel, queue.repeat !== 'off' && styles.modeLabelOn]}>repeat {queue.repeat}</Text>
          </Pressable>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: brand.bg,
  },
  content: {
    paddingHorizontal: 20,
    paddingBottom: 12,
  },
  empty: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 16,
    paddingHorizontal: 20,
  },
  top: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  close: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 15,
  },
  kicker: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 13,
  },
  artWrap: {
    borderRadius: 28,
    overflow: 'hidden',
    backgroundColor: brand.bgCard,
    borderWidth: 1,
    borderColor: brand.line,
  },
  art: {
    width: '100%',
    backgroundColor: brand.bgRaised,
  },
  visualizer: {
    paddingHorizontal: 16,
    paddingBottom: 16,
    paddingTop: 8,
    backgroundColor: 'rgba(7, 6, 13, 0.92)',
  },
  widgetWrap: {
    gap: 10,
  },
  widgetNote: {
    color: brand.dim,
    fontFamily: font.body,
    fontSize: 13,
    lineHeight: 18,
  },
  meta: {
    marginTop: 18,
    gap: 4,
  },
  title: {
    color: brand.text,
    fontFamily: font.bodyBold,
    fontSize: 26,
    lineHeight: 30,
  },
  artist: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 16,
  },
  help: {
    marginTop: 14,
    gap: 8,
    padding: 12,
    borderRadius: 16,
    backgroundColor: brand.bgRaised,
    borderWidth: 1,
    borderColor: brand.lineSoft,
  },
  helpCopy: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 14,
    lineHeight: 20,
  },
  helpAction: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 14,
  },
  scrubBlock: {
    marginTop: 18,
    gap: 8,
  },
  scrub: {
    height: 22,
    borderRadius: 99,
    backgroundColor: brand.bgRaised,
    overflow: 'hidden',
    justifyContent: 'center',
  },
  scrubFill: {
    height: 6,
    borderRadius: 99,
    backgroundColor: brand.magenta,
  },
  times: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  time: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 12,
  },
  transport: {
    marginTop: 18,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  side: {
    minWidth: 72,
    minHeight: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  sideLabel: {
    color: brand.text,
    fontFamily: font.bodyBold,
    fontSize: 16,
  },
  playSpacer: {
    width: 112,
    height: 112,
  },
  play: {
    width: 112,
    height: 112,
    borderRadius: 56,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: brand.magenta,
    boxShadow: '0 0 32px rgba(255, 43, 214, 0.45)',
  },
  playLabel: {
    color: brand.bg,
    fontFamily: font.displayBold,
    fontSize: 22,
  },
  modes: {
    marginTop: 16,
    flexDirection: 'row',
    gap: 10,
  },
  mode: {
    borderRadius: 999,
    borderWidth: 1,
    borderColor: brand.lineSoft,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  modeOn: {
    backgroundColor: brand.cyan,
    borderColor: brand.cyan,
  },
  modeLabel: {
    color: brand.text,
    fontFamily: font.bodyBold,
    fontSize: 14,
  },
  modeLabelOn: {
    color: brand.bg,
  },
});

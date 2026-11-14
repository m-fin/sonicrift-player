import { Image } from 'expo-image';
import { router } from 'expo-router';
import { useRef } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { brand, font, formatClock } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';
import { SoundCloudWidget } from '@/ui/SoundCloudWidget';
import { Visualizer } from '@/ui/Visualizer';

function seedFrom(value: string): number {
  return value.split('').reduce((sum, char) => sum + char.charCodeAt(0), 0);
}

export default function NowPlayingScreen() {
  const insets = useSafeAreaInsets();
  const { current, widgetTrack, status, togglePlay, next, previous, seek, toggleShuffleMode, cycleRepeatMode, queue, shareTrack } =
    usePlayer();
  const scrubWidth = useRef(1);

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

  return (
    <View style={[styles.screen, { paddingTop: insets.top + 8, paddingBottom: insets.bottom + 16 }]}>
      <View style={styles.top}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close now playing" onPress={() => router.back()} hitSlop={12}>
          <Text style={styles.close}>close</Text>
        </Pressable>
        <Text style={styles.kicker}>{current.placeholder ? 'placeholder' : 'now playing'}</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Share ${current.title}`}
          onPress={() => {
            void shareTrack(current);
          }}
          hitSlop={12}>
          <Text style={styles.close}>share</Text>
        </Pressable>
      </View>

      {widget ? (
        <View style={styles.widgetWrap}>
          <SoundCloudWidget pageUrl={current.permalink} height={360} />
          <Text style={styles.widgetNote}>official soundcloud player. this track is not streamed through a private api.</Text>
        </View>
      ) : (
        <View style={styles.artWrap}>
          <Image
            source={current.artworkUrl ? { uri: current.artworkUrl } : require('../../assets/images/icon.png')}
            style={styles.art}
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

      {widget ? null : (
        <View style={styles.scrubBlock}>
          <Pressable
            accessibilityRole="adjustable"
            accessibilityLabel="Seek"
            onLayout={(event) => {
              scrubWidth.current = event.nativeEvent.layout.width || 1;
            }}
            onPress={(event) => {
              const ratio = Math.min(1, Math.max(0, event.nativeEvent.locationX / scrubWidth.current));
              seek(ratio * duration);
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
            <Text style={styles.playLabel}>{status.playing ? 'pause' : 'play'}</Text>
          </Pressable>
        )}
        <Pressable accessibilityRole="button" accessibilityLabel="Next" onPress={next} style={styles.side}>
          <Text style={styles.sideLabel}>next</Text>
        </Pressable>
      </View>

      <View style={styles.modes}>
        <Text style={styles.mode}>{queue.shuffle ? 'shuffle on' : 'shuffle off'}</Text>
        <Pressable accessibilityRole="button" accessibilityLabel="Toggle shuffle" onPress={toggleShuffleMode}>
          <Text style={styles.modeAction}>shuffle</Text>
        </Pressable>
        <Pressable accessibilityRole="button" accessibilityLabel="Cycle repeat" onPress={cycleRepeatMode}>
          <Text style={styles.modeAction}>repeat {queue.repeat}</Text>
        </Pressable>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: brand.bg,
    paddingHorizontal: 20,
  },
  empty: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 16,
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
    aspectRatio: 1,
    backgroundColor: brand.bgRaised,
  },
  artFallback: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  rift: {
    color: brand.magenta,
    fontFamily: font.display,
    fontSize: 40,
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
  scrubBlock: {
    marginTop: 18,
    gap: 8,
  },
  scrub: {
    height: 18,
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
    alignItems: 'center',
    paddingVertical: 12,
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
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  mode: {
    color: brand.dim,
    fontFamily: font.body,
    fontSize: 13,
  },
  modeAction: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 14,
  },
});

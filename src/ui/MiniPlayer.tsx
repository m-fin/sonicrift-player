import { Image } from 'expo-image';
import { router } from 'expo-router';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { brand, font } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';

export function MiniPlayer() {
  const { current, status, togglePlay, widgetTrack, engaged } = usePlayer();
  if (!current || !engaged) return null;
  const playing = !widgetTrack && status.playing;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel="Open now playing"
      onPress={() => router.push('/now-playing')}
      style={styles.bar}>
      <Image
        source={current.artworkUrl ? { uri: current.artworkUrl } : require('../../assets/images/icon.png')}
        style={styles.art}
      />
      <View style={styles.copy}>
        <Text style={styles.kicker}>{current.placeholder ? 'placeholder' : 'sonicrift'}</Text>
        <Text style={styles.title} numberOfLines={1}>
          {current.title}
        </Text>
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={playing ? 'Pause' : 'Play'}
        hitSlop={10}
        onPress={(event) => {
          event.stopPropagation();
          if (widgetTrack) {
            router.push('/now-playing');
            return;
          }
          togglePlay();
        }}
        style={styles.play}>
        <Text style={styles.playLabel}>{playing ? 'pause' : 'play'}</Text>
      </Pressable>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  bar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginHorizontal: 16,
    marginBottom: 8,
    padding: 8,
    paddingRight: 12,
    borderRadius: 22,
    backgroundColor: 'rgba(18, 15, 28, 0.94)',
    borderWidth: 1,
    borderColor: brand.line,
  },
  art: {
    width: 46,
    height: 46,
    borderRadius: 14,
  },
  fallback: {
    backgroundColor: brand.magenta,
  },
  copy: {
    flex: 1,
    gap: 2,
  },
  kicker: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 11,
  },
  title: {
    color: brand.text,
    fontFamily: font.bodyBold,
    fontSize: 15,
  },
  play: {
    minWidth: 64,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    borderRadius: 999,
    backgroundColor: brand.magenta,
  },
  playLabel: {
    color: brand.bg,
    fontFamily: font.bodyBold,
    fontSize: 13,
  },
});

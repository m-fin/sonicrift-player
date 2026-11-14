import { Image } from 'expo-image';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { brand, font, formatDuration } from '@/constants/theme';
import type { Track } from '@/sources/catalog';

export function TrackRow({
  track,
  active,
  onPress,
}: {
  track: Track;
  active?: boolean;
  onPress: () => void;
}) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityLabel={`Play ${track.title}`}
      onPress={onPress}
      style={({ pressed }) => [styles.row, active && styles.active, pressed && styles.pressed]}>
      <Image
        source={track.artworkUrl ? { uri: track.artworkUrl } : require('../../assets/images/icon.png')}
        style={styles.art}
        accessibilityLabel=""
      />
      <View style={styles.copy}>
        <Text style={styles.title} numberOfLines={1}>
          {track.title}
        </Text>
        <Text style={styles.meta} numberOfLines={1}>
          {track.placeholder ? 'placeholder tone' : 'sonicrift'}
          {'  ·  '}
          {formatDuration(track.durationMs)}
        </Text>
      </View>
      {active ? <Text style={styles.now}>now</Text> : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 18,
  },
  active: {
    backgroundColor: 'rgba(255, 43, 214, 0.12)',
  },
  pressed: {
    opacity: 0.72,
  },
  art: {
    width: 52,
    height: 52,
    borderRadius: 14,
    backgroundColor: brand.bgCard,
  },
  artFallback: {
    borderWidth: 1,
    borderColor: brand.line,
  },
  copy: {
    flex: 1,
    gap: 3,
  },
  title: {
    color: brand.text,
    fontFamily: font.bodyBold,
    fontSize: 16,
  },
  meta: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 13,
  },
  now: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 12,
  },
});

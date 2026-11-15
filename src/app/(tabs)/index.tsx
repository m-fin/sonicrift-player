import { Image } from 'expo-image';
import { router } from 'expo-router';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { brand, font, formatDuration } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';
import { SOUNDCLOUD_SNAPSHOT_CAPTURED_AT } from '@/sources/soundcloud-snapshot';
import type { Track } from '@/sources/catalog';
import { Screen } from '@/ui/Screen';
import { TrackRow } from '@/ui/TrackRow';

function openTrack(id: string, playTrack: (id: string) => void) {
  playTrack(id);
  router.push('/now-playing');
}

export default function HomeScreen() {
  const { catalog, loading, current, playTrack, engaged } = usePlayer();
  const tracks = catalog?.tracks ?? [];
  const drops = (catalog?.newDropIds ?? [])
    .map((id) => tracks.find((track) => track.id === id))
    .filter((track): track is Track => Boolean(track));
  const featured = drops[0];
  const releases = tracks.filter((track) => !track.placeholder);
  const placeholders = tracks.filter((track) => track.placeholder);
  const usingSnapshot = catalog?.errors.some((error) => error.sourceId === 'soundcloud') ?? false;

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <Text style={styles.eyebrow}>frog finley</Text>
        <Text style={styles.wordmark}>sonicrift</Text>
        <Text style={styles.lede}>public tracks, played in the dark.</Text>

        {loading ? <Text style={styles.notice}>tuning the rift…</Text> : null}
        {usingSnapshot ? (
          <Text style={styles.notice}>
            {Platform.OS === 'web'
              ? `The live SoundCloud feed is blocked in the browser. Playing the public snapshot from ${SOUNDCLOUD_SNAPSHOT_CAPTURED_AT}.`
              : `The live SoundCloud feed did not load. Playing the public snapshot from ${SOUNDCLOUD_SNAPSHOT_CAPTURED_AT}.`}
          </Text>
        ) : null}
        {(catalog?.errors ?? [])
          .filter((error) => error.sourceId !== 'soundcloud')
          .map((error) => (
            <Text key={error.sourceId} style={styles.notice}>
              {error.message}
            </Text>
          ))}

        <Text style={styles.section}>new drop</Text>
        {featured ? (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Play new drop ${featured.title}`}
            onPress={() => openTrack(featured.id, playTrack)}
            style={styles.drop}>
            {featured.artworkUrl ? (
              <Image source={{ uri: featured.artworkUrl }} style={styles.dropArt} />
            ) : (
              <View style={[styles.dropArt, styles.dropFallback]} />
            )}
            <View style={styles.dropShade} />
            <View style={styles.dropCopy}>
              <Text style={styles.pill}>new drop</Text>
              <Text style={styles.dropTitle} numberOfLines={2}>
                {featured.title}
              </Text>
              <Text style={styles.dropMeta}>sonicrift  ·  {formatDuration(featured.durationMs)}</Text>
            </View>
          </Pressable>
        ) : (
          <Text style={styles.empty}>no fresh public drop in the last three weeks.</Text>
        )}

        <Text style={styles.section}>catalog</Text>
        {releases.map((track) => (
          <TrackRow
            key={track.id}
            track={track}
            active={engaged && current?.id === track.id}
            onPress={() => openTrack(track.id, playTrack)}
          />
        ))}

        <Text style={styles.section}>sample tones</Text>
        <Text style={styles.placeholderNote}>
          PLACEHOLDER. Original tones bundled with the app so the player works offline. Not sonicrift releases. Not third-party audio.
        </Text>
        {placeholders.map((track) => (
          <TrackRow
            key={track.id}
            track={track}
            active={engaged && current?.id === track.id}
            onPress={() => openTrack(track.id, playTrack)}
          />
        ))}
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingBottom: 28,
    gap: 8,
  },
  eyebrow: {
    marginTop: 12,
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 13,
    letterSpacing: 0.4,
  },
  wordmark: {
    color: brand.text,
    fontFamily: font.display,
    fontSize: 44,
    lineHeight: 50,
    letterSpacing: -1.4,
  },
  lede: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 16,
    marginBottom: 12,
  },
  notice: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 8,
  },
  section: {
    marginTop: 18,
    marginBottom: 8,
    color: brand.text,
    fontFamily: font.displayBold,
    fontSize: 22,
  },
  drop: {
    height: 232,
    borderRadius: 28,
    overflow: 'hidden',
    backgroundColor: brand.bgCard,
    borderWidth: 1,
    borderColor: brand.line,
  },
  dropArt: {
    ...StyleSheet.absoluteFill,
  },
  dropFallback: {
    backgroundColor: brand.violet,
  },
  dropShade: {
    ...StyleSheet.absoluteFill,
    backgroundColor: 'rgba(7, 6, 13, 0.35)',
  },
  dropCopy: {
    flex: 1,
    justifyContent: 'flex-end',
    padding: 18,
    gap: 6,
  },
  pill: {
    alignSelf: 'flex-start',
    overflow: 'hidden',
    color: brand.bg,
    backgroundColor: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 12,
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 999,
  },
  dropTitle: {
    color: brand.text,
    fontFamily: font.display,
    fontSize: 36,
    lineHeight: 40,
  },
  dropMeta: {
    color: brand.cyan,
    fontFamily: font.body,
    fontSize: 14,
  },
  empty: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 14,
  },
  placeholderNote: {
    color: brand.dim,
    fontFamily: font.body,
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 6,
  },
});

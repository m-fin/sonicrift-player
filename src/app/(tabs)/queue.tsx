import { router } from 'expo-router';
import { Platform, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { brand, font } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';
import { Screen } from '@/ui/Screen';
import { TrackRow } from '@/ui/TrackRow';

export default function QueueScreen() {
  const { queue, catalog, current, playTrack, toggleShuffleMode, cycleRepeatMode, removeFromQueue, engaged } = usePlayer();
  const byId = new Map((catalog?.tracks ?? []).map((track) => [track.id, track]));

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={styles.kicker}>up next</Text>
        <Text style={styles.title}>queue</Text>
        {Platform.OS === 'web' ? (
          <Text style={styles.note}>this browser queues the bundled tones. iphone queues the public feed.</Text>
        ) : null}
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
            <Text style={[styles.modeLabel, queue.repeat !== 'off' && styles.modeLabelOn]}>
              repeat {queue.repeat}
            </Text>
          </Pressable>
        </View>
        {queue.order.length === 0 ? (
          <Text style={styles.empty}>the queue fills when the catalog loads.</Text>
        ) : (
          queue.order.map((id, index) => {
            const track = byId.get(id);
            if (!track) return null;
            const active = engaged && current?.id === id;
            return (
              <View key={id} style={styles.item}>
                <View style={styles.rowWrap}>
                  <TrackRow
                    track={track}
                    active={active}
                    onPress={() => {
                      playTrack(id);
                      router.push('/now-playing');
                    }}
                  />
                </View>
                <Pressable
                  accessibilityRole="button"
                  accessibilityLabel={`Remove ${track.title} from queue`}
                  onPress={() => removeFromQueue(index)}
                  style={styles.remove}>
                  <Text style={styles.removeLabel}>remove</Text>
                </Pressable>
              </View>
            );
          })
        )}
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingBottom: 24,
  },
  kicker: {
    marginTop: 12,
    color: brand.magenta,
    fontFamily: font.bodyBold,
    fontSize: 13,
  },
  note: {
    color: brand.dim,
    fontFamily: font.body,
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 12,
  },
  title: {
    color: brand.text,
    fontFamily: font.display,
    fontSize: 48,
    letterSpacing: -1.5,
    marginBottom: 12,
  },
  modes: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 16,
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
  empty: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 15,
  },
  item: {
    marginBottom: 4,
  },
  rowWrap: {
    marginRight: 72,
  },
  remove: {
    position: 'absolute',
    right: 0,
    top: 22,
  },
  removeLabel: {
    color: brand.danger,
    fontFamily: font.bodyBold,
    fontSize: 13,
  },
});

import { StyleSheet, View, type ViewProps } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { brand } from '@/constants/theme';
import { MiniPlayer } from '@/ui/MiniPlayer';

export function Screen({ children, style }: ViewProps) {
  const insets = useSafeAreaInsets();
  return (
    <View style={[styles.screen, { paddingTop: insets.top }, style]}>
      <View style={styles.body}>{children}</View>
      <View style={{ paddingBottom: Math.max(insets.bottom, 8) }}>
        <MiniPlayer />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: brand.bg,
  },
  body: {
    flex: 1,
  },
});

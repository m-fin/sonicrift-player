import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, { useAnimatedStyle, useFrameCallback, useSharedValue, type SharedValue } from 'react-native-reanimated';

import { brand } from '@/constants/theme';

const BARS = 28;

function Bar({ index, clock, active, seed }: { index: number; clock: SharedValue<number>; active: SharedValue<number>; seed: number }) {
  const style = useAnimatedStyle(() => {
    const speed = 0.003 + (index % 6) * 0.0007;
    const wave = Math.sin(clock.value * speed + seed + index * 0.47);
    const flutter = Math.sin(clock.value * 0.0017 + index);
    const idle = 0.16 + Math.abs(Math.sin(seed + index * 0.55)) * 0.42;
    const energy = active.value > 0 ? 0.28 + Math.abs(wave) * 0.52 + Math.abs(flutter) * 0.2 : idle;
    return {
      height: 6 + energy * 78,
      opacity: active.value > 0 ? 0.75 + energy * 0.25 : 0.28,
    };
  });
  const color = index % 7 === 0 ? brand.violet : index < BARS / 2 ? brand.magenta : brand.cyan;
  return <Animated.View style={[styles.bar, { backgroundColor: color }, style]} />;
}

export function Visualizer({ playing, seed }: { playing: boolean; seed: number }) {
  const clock = useSharedValue(0);
  const active = useSharedValue(playing ? 1 : 0);

  useEffect(() => {
    active.value = playing ? 1 : 0;
  }, [active, playing]);

  useFrameCallback((frame) => {
    if (active.value > 0) {
      clock.value += frame.timeSincePreviousFrame ?? 16;
    }
  });

  return (
    <View style={styles.row} accessibilityLabel={playing ? 'Audio visualizer playing' : 'Audio visualizer idle'}>
      {Array.from({ length: BARS }, (_, index) => (
        <Bar key={index} index={index} clock={clock} active={active} seed={seed} />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    height: 92,
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    gap: 3,
  },
  bar: {
    flex: 1,
    borderRadius: 99,
    minHeight: 6,
  },
});

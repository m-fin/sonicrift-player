import { createElement } from 'react';
import { StyleSheet, View } from 'react-native';

import { brand } from '@/constants/theme';
import { widgetSrc } from '@/ui/widget-src';

export function SoundCloudWidget({ pageUrl, height = 420 }: { pageUrl: string; height?: number }) {
  return (
    <View style={[styles.frame, { height }]}>
      {createElement('iframe', {
        title: 'sonicrift on SoundCloud',
        src: widgetSrc(pageUrl),
        width: '100%',
        height: '100%',
        allow: 'autoplay; encrypted-media',
        style: { border: 0, width: '100%', height: '100%', background: brand.bg },
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  frame: {
    overflow: 'hidden',
    borderRadius: 22,
    backgroundColor: brand.bgRaised,
    borderWidth: 1,
    borderColor: brand.lineSoft,
  },
});

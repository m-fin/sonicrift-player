import { StyleSheet, View } from 'react-native';
import { WebView } from 'react-native-webview';

import { brand } from '@/constants/theme';
import { widgetSrc } from '@/ui/widget-src';

export function SoundCloudWidget({ pageUrl, height = 420 }: { pageUrl: string; height?: number }) {
  return (
    <View style={[styles.frame, { height }]}>
      <WebView
        source={{ uri: widgetSrc(pageUrl) }}
        style={styles.web}
        allowsInlineMediaPlayback
        mediaPlaybackRequiresUserAction={false}
        originWhitelist={['*']}
        setSupportMultipleWindows={false}
      />
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
  web: {
    flex: 1,
    backgroundColor: 'transparent',
  },
});

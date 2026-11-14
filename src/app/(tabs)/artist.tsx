import { Image } from 'expo-image';
import * as WebBrowser from 'expo-web-browser';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';

import { artistLinks, artistParagraphs } from '@/content/artist';
import { brand, font } from '@/constants/theme';
import { usePlayer } from '@/player/PlayerProvider';
import { Screen } from '@/ui/Screen';
import { SoundCloudWidget } from '@/ui/SoundCloudWidget';

export default function ArtistScreen() {
  const { catalog } = usePlayer();
  const profile = catalog?.profile;
  const portrait = profile?.thumbnail_url;
  const embed = catalog?.tracks.find((track) => !track.placeholder);

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.hero}>
          {portrait ? <Image source={{ uri: portrait }} style={styles.portrait} accessibilityLabel="sonicrift" /> : <View style={styles.portrait} />}
          <View style={styles.identity}>
            <Text style={styles.kicker}>artist</Text>
            <Text style={styles.name}>sonicrift</Text>
          </View>
        </View>
        {artistParagraphs.map((paragraph) => (
          <Text key={paragraph} style={styles.body}>
            {paragraph}
          </Text>
        ))}
        <View style={styles.links}>
          {artistLinks.map((link) => (
            <Pressable
              key={link.url}
              accessibilityRole="link"
              accessibilityLabel={link.label}
              onPress={() => {
                void WebBrowser.openBrowserAsync(link.url);
              }}
              style={styles.link}>
              <Text style={styles.linkLabel}>{link.label}</Text>
            </Pressable>
          ))}
        </View>
        <Text style={styles.section}>on soundcloud</Text>
        {embed ? <SoundCloudWidget pageUrl={embed.permalink} height={380} /> : null}
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingHorizontal: 20,
    paddingBottom: 28,
    gap: 12,
  },
  hero: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginTop: 16,
  },
  portrait: {
    width: 84,
    height: 84,
    borderRadius: 42,
    backgroundColor: brand.bgCard,
    borderWidth: 1,
    borderColor: brand.line,
  },
  identity: {
    flex: 1,
  },
  kicker: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 13,
  },
  name: {
    color: brand.text,
    fontFamily: font.display,
    fontSize: 30,
    lineHeight: 34,
    letterSpacing: -1,
  },
  body: {
    color: brand.muted,
    fontFamily: font.body,
    fontSize: 16,
    lineHeight: 23,
  },
  links: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 4,
  },
  link: {
    borderRadius: 999,
    backgroundColor: brand.bgRaised,
    borderWidth: 1,
    borderColor: brand.lineSoft,
    paddingHorizontal: 14,
    paddingVertical: 8,
  },
  linkLabel: {
    color: brand.cyan,
    fontFamily: font.bodyBold,
    fontSize: 14,
  },
  section: {
    marginTop: 8,
    color: brand.text,
    fontFamily: font.displayBold,
    fontSize: 22,
  },
});

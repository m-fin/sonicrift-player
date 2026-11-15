import { Tabs } from 'expo-router';
import { Text, type ColorValue } from 'react-native';

import { brand, font } from '@/constants/theme';

function TabGlyph({ color, glyph }: { color: ColorValue; glyph: string }) {
  return <Text style={{ color, fontFamily: font.bodyBold, fontSize: 16 }}>{glyph}</Text>;
}

export default function WebTabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: brand.cyan,
        tabBarInactiveTintColor: brand.muted,
        tabBarStyle: {
          backgroundColor: brand.bgRaised,
          borderTopColor: brand.lineSoft,
          height: 64,
        },
        tabBarLabelStyle: {
          fontFamily: font.bodyBold,
          fontSize: 13,
        },
      }}>
      <Tabs.Screen
        name="index"
        options={{
          title: 'home',
          tabBarIcon: ({ color }) => <TabGlyph color={color} glyph="~" />,
        }}
      />
      <Tabs.Screen
        name="queue"
        options={{
          title: 'queue',
          tabBarIcon: ({ color }) => <TabGlyph color={color} glyph="≡" />,
        }}
      />
      <Tabs.Screen
        name="artist"
        options={{
          title: 'artist',
          tabBarIcon: ({ color }) => <TabGlyph color={color} glyph="◦" />,
        }}
      />
    </Tabs>
  );
}

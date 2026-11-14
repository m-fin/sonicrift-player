import { Tabs } from 'expo-router';
import { Text } from 'react-native';

import { brand, font } from '@/constants/theme';

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
        tabBarIcon: ({ color }) => <Text style={{ color, fontSize: 16 }}>•</Text>,
        tabBarLabelStyle: {
          fontFamily: font.bodyBold,
          fontSize: 13,
        },
      }}>
      <Tabs.Screen name="index" options={{ title: 'home' }} />
      <Tabs.Screen name="queue" options={{ title: 'queue' }} />
      <Tabs.Screen name="artist" options={{ title: 'artist' }} />
    </Tabs>
  );
}

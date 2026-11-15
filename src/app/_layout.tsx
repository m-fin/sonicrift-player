import { Syne_700Bold, Syne_800ExtraBold } from '@expo-google-fonts/syne';
import { Manrope_500Medium, Manrope_700Bold } from '@expo-google-fonts/manrope';
import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';

import { brand } from '@/constants/theme';
import { PlayerProvider } from '@/player/PlayerProvider';

import '@/styles/global-style';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [fontsLoaded, fontError] = useFonts({
    Syne_800ExtraBold,
    Syne_700Bold,
    Manrope_500Medium,
    Manrope_700Bold,
  });

  useEffect(() => {
    if (fontsLoaded || fontError) {
      void SplashScreen.hideAsync();
    }
  }, [fontError, fontsLoaded]);

  if (!fontsLoaded && !fontError) return null;

  return (
    <PlayerProvider>
      <StatusBar style="light" />
      <View style={styles.frame}>
        <View style={styles.column}>
          <Stack
            screenOptions={{
              headerShown: false,
              contentStyle: { backgroundColor: brand.bg },
            }}>
            <Stack.Screen name="(tabs)" />
            <Stack.Screen
              name="now-playing"
              options={{ presentation: 'modal', animation: 'slide_from_bottom' }}
            />
          </Stack>
        </View>
      </View>
    </PlayerProvider>
  );
}

const styles = StyleSheet.create({
  frame: {
    flex: 1,
    alignItems: 'center',
    backgroundColor: brand.bg,
  },
  column: {
    flex: 1,
    width: '100%',
    maxWidth: 480,
    backgroundColor: brand.bg,
  },
});

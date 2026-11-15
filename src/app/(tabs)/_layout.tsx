import { NativeTabs } from 'expo-router/native-tabs';

import { brand } from '@/constants/theme';

export default function TabsLayout() {
  return (
    <NativeTabs
      backgroundColor={brand.bg}
      indicatorColor={brand.magenta}
      iconColor={{ default: brand.muted, selected: brand.cyan }}
      labelStyle={{ color: brand.muted, fontSize: 11 }}
      tintColor={brand.cyan}>
      <NativeTabs.Trigger name="index">
        <NativeTabs.Trigger.Label>home</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="waveform" md="graphic_eq" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="queue">
        <NativeTabs.Trigger.Label>queue</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="list.bullet" md="queue_music" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="artist">
        <NativeTabs.Trigger.Label>artist</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="person.crop.circle" md="person" />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}

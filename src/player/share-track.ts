import { Platform, Share } from 'react-native';

export type ShareResult = 'shared' | 'copied' | 'unavailable';

export async function shareTrackLink(track: { title: string; permalink: string }): Promise<ShareResult> {
  const message = `${track.title} — sonicrift`;
  const full = `${message}\n${track.permalink}`;
  try {
    const result = await Share.share(
      Platform.OS === 'ios'
        ? { title: track.title, message, url: track.permalink }
        : { title: track.title, message: full },
    );
    if (result.action === Share.dismissedAction) return 'unavailable';
    return 'shared';
  } catch {
    const clipboard = globalThis.navigator?.clipboard;
    if (!clipboard?.writeText) return 'unavailable';
    await clipboard.writeText(full);
    return 'copied';
  }
}

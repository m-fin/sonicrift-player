export type PlaybackKeys = {
  toggle: () => void;
  seekBy: (seconds: number) => void;
};

/** Native playback uses the on-screen controls and the lock screen. */
export function bindPlaybackKeys(handlers: PlaybackKeys): () => void {
  void handlers;
  return () => undefined;
}

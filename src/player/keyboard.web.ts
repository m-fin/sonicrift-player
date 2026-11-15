type PlaybackKeys = {
  toggle: () => void;
  seekBy: (seconds: number) => void;
};

function isTypingTarget(target: EventTarget | null): boolean {
  if (!(target instanceof Element)) return false;
  return Boolean(target.closest('input, textarea, select, button, a, [role="button"], [contenteditable="true"]'));
}

/** Space toggles playback. Arrow keys seek. Ignored while typing. */
export function bindPlaybackKeys(handlers: PlaybackKeys): () => void {
  const onKey = (event: KeyboardEvent) => {
    if (event.repeat || event.metaKey || event.ctrlKey || event.altKey) return;
    if (isTypingTarget(event.target)) return;
    if (event.code === 'Space') {
      event.preventDefault();
      handlers.toggle();
      return;
    }
    if (event.code === 'ArrowRight') {
      event.preventDefault();
      handlers.seekBy(5);
      return;
    }
    if (event.code === 'ArrowLeft') {
      event.preventDefault();
      handlers.seekBy(-5);
    }
  };
  window.addEventListener('keydown', onKey);
  return () => window.removeEventListener('keydown', onKey);
}

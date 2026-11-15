import type { RepeatMode } from '@/domain/queue';

export type PlaylistLoop = 'none' | 'single' | 'all';

export function loopForRepeat(repeat: RepeatMode): PlaylistLoop {
  if (repeat === 'one') return 'single';
  if (repeat === 'all') return 'all';
  return 'none';
}

/**
 * Decides where a freshly built playlist should sit, and whether it should start.
 * A requested track wins over whatever was playing before the queue changed.
 */
export function playlistSyncPlan(input: {
  order: string[];
  index: number;
  repeat: RepeatMode;
  wasPlaying: boolean;
  requestedId?: string | null;
}): { index: number; play: boolean; loop: PlaylistLoop } {
  const requested = input.requestedId ? input.order.indexOf(input.requestedId) : -1;
  const fallback =
    input.order.length === 0 ? 0 : Math.min(Math.max(input.index, 0), input.order.length - 1);
  return {
    index: requested >= 0 ? requested : fallback,
    play: requested >= 0 || input.wasPlaying,
    loop: loopForRepeat(input.repeat),
  };
}

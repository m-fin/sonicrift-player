export type RepeatMode = 'off' | 'one' | 'all';

export type QueueState = {
  /** Catalog order, used when shuffle is off. */
  linearOrder: string[];
  /** Order actually played. */
  order: string[];
  index: number;
  repeat: RepeatMode;
  shuffle: boolean;
};

export function createQueue(ids: string[]): QueueState {
  return {
    linearOrder: [...ids],
    order: [...ids],
    index: 0,
    repeat: 'off',
    shuffle: false,
  };
}

export function cycleRepeat(mode: RepeatMode): RepeatMode {
  if (mode === 'off') return 'one';
  if (mode === 'one') return 'all';
  return 'off';
}

function shuffleIds(ids: string[], rng: () => number): string[] {
  const next = [...ids];
  for (let i = next.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    const swap = next[i];
    next[i] = next[j] ?? next[i];
    next[j] = swap ?? next[j];
  }
  return next;
}

/** Keeps the current track in place and shuffles everything after it. */
export function toggleShuffle(state: QueueState, rng: () => number = Math.random): QueueState {
  if (state.order.length === 0) {
    return { ...state, shuffle: !state.shuffle };
  }
  const currentId = state.order[state.index];
  if (!state.shuffle) {
    const rest = state.order.filter((id) => id !== currentId);
    const shuffled = shuffleIds(rest, rng);
    const order = currentId ? [currentId, ...shuffled] : shuffled;
    return { ...state, shuffle: true, order, index: 0 };
  }
  const index = currentId ? Math.max(0, state.linearOrder.indexOf(currentId)) : 0;
  return {
    ...state,
    shuffle: false,
    order: [...state.linearOrder],
    index: index === -1 ? 0 : index,
  };
}

export function nextIndex(state: QueueState): number | null {
  if (state.order.length === 0) return null;
  if (state.repeat === 'one') return state.index;
  const upcoming = state.index + 1;
  if (upcoming < state.order.length) return upcoming;
  if (state.repeat === 'all') return 0;
  return null;
}

export function previousTarget(
  state: QueueState,
  currentTimeSec: number,
  restartThresholdSec = 3,
): { index: number; restart: boolean } {
  if (state.order.length === 0) return { index: 0, restart: true };
  if (currentTimeSec > restartThresholdSec) return { index: state.index, restart: true };
  if (state.repeat === 'one') return { index: state.index, restart: true };
  if (state.index > 0) return { index: state.index - 1, restart: false };
  if (state.repeat === 'all') return { index: state.order.length - 1, restart: false };
  return { index: 0, restart: true };
}

export function playId(state: QueueState, id: string): QueueState {
  const index = state.order.indexOf(id);
  if (index === -1) return state;
  return { ...state, index };
}

export function removeAt(state: QueueState, index: number): QueueState {
  if (index < 0 || index >= state.order.length) return state;
  const removed = state.order[index];
  const order = state.order.filter((_, i) => i !== index);
  const linearOrder = state.linearOrder.filter((id) => id !== removed);
  let next = state.index;
  if (index < state.index) next -= 1;
  if (next >= order.length) next = Math.max(0, order.length - 1);
  return { ...state, order, linearOrder, index: next };
}

export function replaceOrder(state: QueueState, ids: string[], keepId?: string): QueueState {
  const linearOrder = [...ids];
  const order = state.shuffle ? state.order.filter((id) => ids.includes(id)) : [...ids];
  for (const id of ids) {
    if (!order.includes(id)) order.push(id);
  }
  const pruned = order.filter((id) => ids.includes(id));
  const focus = keepId && pruned.includes(keepId) ? keepId : pruned[state.index];
  const index = focus ? Math.max(0, pruned.indexOf(focus)) : 0;
  return { ...state, linearOrder, order: pruned, index };
}

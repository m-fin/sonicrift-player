import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createQueue,
  cycleRepeat,
  nextIndex,
  playId,
  previousTarget,
  removeAt,
  toggleShuffle,
} from './queue';

test('repeat cycles off, one, all', () => {
  assert.equal(cycleRepeat('off'), 'one');
  assert.equal(cycleRepeat('one'), 'all');
  assert.equal(cycleRepeat('all'), 'off');
});

test('next stops at the end when repeat is off', () => {
  const queue = createQueue(['a', 'b']);
  assert.equal(nextIndex(queue), 1);
  assert.equal(nextIndex({ ...queue, index: 1 }), null);
});

test('repeat one stays on the current track', () => {
  const queue = { ...createQueue(['a', 'b']), repeat: 'one' as const, index: 0 };
  assert.equal(nextIndex(queue), 0);
});

test('repeat all wraps to the start', () => {
  const queue = { ...createQueue(['a', 'b']), repeat: 'all' as const, index: 1 };
  assert.equal(nextIndex(queue), 0);
});

test('previous restarts the current track after three seconds', () => {
  const queue = { ...createQueue(['a', 'b']), index: 1 };
  assert.deepEqual(previousTarget(queue, 4), { index: 1, restart: true });
  assert.deepEqual(previousTarget(queue, 1), { index: 0, restart: false });
});

test('previous wraps when repeat is all', () => {
  const queue = { ...createQueue(['a', 'b']), repeat: 'all' as const, index: 0 };
  assert.deepEqual(previousTarget(queue, 0), { index: 1, restart: false });
});

test('shuffle keeps the current track first and can be undone', () => {
  const rng = () => 0;
  const shuffled = toggleShuffle({ ...createQueue(['a', 'b', 'c']), index: 1 }, rng);
  assert.equal(shuffled.shuffle, true);
  assert.equal(shuffled.order[0], 'b');
  assert.equal(shuffled.index, 0);
  assert.deepEqual(shuffled.order.slice().sort(), ['a', 'b', 'c']);
  const restored = toggleShuffle(shuffled, rng);
  assert.equal(restored.shuffle, false);
  assert.deepEqual(restored.order, ['a', 'b', 'c']);
  assert.equal(restored.index, 1);
});

test('playId moves the index and removeAt drops a track', () => {
  const queued = playId(createQueue(['a', 'b', 'c']), 'c');
  assert.equal(queued.index, 2);
  const removed = removeAt(queued, 0);
  assert.deepEqual(removed.order, ['b', 'c']);
  assert.equal(removed.order[removed.index], 'c');
});

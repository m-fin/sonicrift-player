import assert from 'node:assert/strict';
import test from 'node:test';

import { playlistSyncPlan } from './playlist-sync';

test('a requested track starts even when nothing was playing', () => {
  const plan = playlistSyncPlan({
    order: ['a', 'b', 'c'],
    index: 0,
    repeat: 'off',
    wasPlaying: false,
    requestedId: 'c',
  });
  assert.deepEqual(plan, { index: 2, play: true, loop: 'none' });
});

test('an in-progress queue resumes at the same index', () => {
  const plan = playlistSyncPlan({
    order: ['a', 'b'],
    index: 1,
    repeat: 'all',
    wasPlaying: true,
  });
  assert.deepEqual(plan, { index: 1, play: true, loop: 'all' });
});

test('loading the catalog does not autoplay', () => {
  const plan = playlistSyncPlan({
    order: ['a', 'b'],
    index: 0,
    repeat: 'one',
    wasPlaying: false,
  });
  assert.equal(plan.play, false);
  assert.equal(plan.loop, 'single');
  assert.equal(plan.index, 0);
});

test('an unknown request falls back to the current index', () => {
  const plan = playlistSyncPlan({
    order: ['a'],
    index: 4,
    repeat: 'off',
    wasPlaying: false,
    requestedId: 'missing',
  });
  assert.deepEqual(plan, { index: 0, play: false, loop: 'none' });
});

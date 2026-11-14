import assert from 'node:assert/strict';
import test from 'node:test';

import { isThirdPartyAudio, selectNewDropIds } from './policy';

test('keeps sonicrift originals and rejects credited third-party audio', () => {
  assert.equal(isThirdPartyAudio({ title: 'Bionic Body', description: 'Made entirely with code in Python.' }), false);
  assert.equal(isThirdPartyAudio({ title: 'Machine Sleep' }), false);
  assert.equal(isThirdPartyAudio({ title: 'sonicrift - night loop' }), false);
  assert.equal(
    isThirdPartyAudio({
      title: 'Yeat - Real Geek (prod. Ice Cream) [Slowed Instrumental]',
      description: 'Clean slowed instrumental. All rights to the original artists, no copyright infringement intended.',
    }),
    true,
  );
  assert.equal(
    isThirdPartyAudio({
      title: 'Night Drive',
      description: 'A slowed instrumental of "Real Geek". No copyright infringement intended.',
    }),
    true,
  );
});

test('new drop is the recent non-placeholder release', () => {
  const now = Date.parse('2026-11-14T00:00:00.000Z');
  const ids = selectNewDropIds(
    [
      { id: 'old', releasedAt: '2026-09-01T00:00:00.000Z', placeholder: false },
      { id: 'bionic', releasedAt: '2026-11-01T21:17:25.000Z', placeholder: false },
      { id: 'tone', releasedAt: '2026-11-13T00:00:00.000Z', placeholder: true, newDrop: true },
      { id: 'flagged', releasedAt: '2026-01-01T00:00:00.000Z', placeholder: false, newDrop: true },
    ],
    now,
  );
  assert.deepEqual(ids, ['bionic', 'flagged']);
});

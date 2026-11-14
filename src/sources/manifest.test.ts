import assert from 'node:assert/strict';
import test from 'node:test';

import { parseManifest } from './manifest';
import sample from './sample-manifest.json' with { type: 'json' };

test('sample manifest is explicitly placeholder-only', () => {
  const manifest = parseManifest(sample);
  assert.equal(manifest.schema, 'sonicrift.tracks/v1');
  assert.ok(manifest.note?.includes('SAMPLE MANIFEST'));
  assert.ok(manifest.tracks.length >= 2);
  for (const track of manifest.tracks) {
    assert.equal(track.placeholder, true);
    assert.match(track.title, /PLACEHOLDER/);
    assert.match(track.note ?? '', /Not a sonicrift release/);
    assert.equal(track.artist, 'sonicrift');
  }
});

test('manifest rejects a missing placeholder flag', () => {
  assert.throws(
    () =>
      parseManifest({
        schema: 'sonicrift.tracks/v1',
        tracks: [{ id: 'x', title: 'x' }],
      }),
    /placeholder/,
  );
});

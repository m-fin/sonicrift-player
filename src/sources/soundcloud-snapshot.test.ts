import assert from 'node:assert/strict';
import test from 'node:test';

import { isThirdPartyAudio } from '../domain/policy';
import { SOUNDCLOUD_SNAPSHOT_CAPTURED_AT, loadSoundCloudSnapshot } from './soundcloud-snapshot';

test('snapshot keeps sonicrift originals and no third-party audio', () => {
  const { tracks, profile } = loadSoundCloudSnapshot();
  assert.equal(profile.author_name, 'sonicrift');
  assert.equal(SOUNDCLOUD_SNAPSHOT_CAPTURED_AT, '2026-11-14');
  assert.deepEqual(
    tracks.map((track) => track.title),
    ['Bionic Body', 'Machine Sleep', 'Space Drift'],
  );
  for (const track of tracks) {
    assert.equal(track.placeholder, false);
    assert.equal(track.artist, 'sonicrift');
    assert.equal(isThirdPartyAudio(track), false);
    assert.equal(track.playback.kind, 'remote');
  }
});

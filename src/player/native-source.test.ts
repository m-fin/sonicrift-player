import assert from 'node:assert/strict';
import test from 'node:test';

import {
  addPlaylistSources,
  nowPlayingMetadata,
  playlistAudioSource,
  sourceForPlayback,
  type PlaylistAudioSource,
} from './native-source';

const remote = 'https://feeds.soundcloud.com/stream/2430434229-sonicrift-bionic-body.mp3';

test('a remote stream is an audio source record, not a bare URL string', () => {
  const source = playlistAudioSource(remote);
  assert.deepEqual(source, { uri: remote });
  assert.equal(typeof source, 'object');
});

test('a bundled asset id is not passed through to playlist.add', () => {
  assert.equal(playlistAudioSource(7), null);
});

test('missing, empty, and non-string uris are dropped', () => {
  assert.equal(playlistAudioSource(undefined), null);
  assert.equal(playlistAudioSource(null), null);
  assert.equal(playlistAudioSource(''), null);
  assert.equal(playlistAudioSource('   '), null);
  assert.equal(playlistAudioSource({ uri: undefined }), null);
  assert.equal(playlistAudioSource({ uri: 7 }), null);
  assert.equal(playlistAudioSource({ uri: { url: remote } }), null);
  assert.equal(playlistAudioSource({ href: remote }), null);
});

test('file URIs and absolute paths stay playable local sources', () => {
  assert.deepEqual(playlistAudioSource('file:///App.app/assets/audio/tone.wav'), {
    uri: 'file:///App.app/assets/audio/tone.wav',
  });
  assert.deepEqual(playlistAudioSource('/assets/audio/tone.wav'), {
    uri: '/assets/audio/tone.wav',
  });
});

test('a remote track queues and a bad or missing one does not', () => {
  const bundled = new Map<string, unknown>([
    ['placeholder-rift-tone', 'file:///App.app/assets/audio/placeholder-rift-tone.wav'],
    ['missing-tone', null],
  ]);
  assert.deepEqual(
    sourceForPlayback({ kind: 'remote', uri: remote }, (key) => bundled.get(key)),
    { uri: remote },
  );
  assert.equal(sourceForPlayback({ kind: 'remote', uri: undefined }, () => null), null);
  assert.equal(sourceForPlayback({ kind: 'remote', uri: { url: remote } }, () => null), null);
  assert.deepEqual(
    sourceForPlayback({ kind: 'bundled', assetKey: 'placeholder-rift-tone' }, (key) => bundled.get(key)),
    { uri: 'file:///App.app/assets/audio/placeholder-rift-tone.wav' },
  );
  assert.equal(sourceForPlayback({ kind: 'bundled', assetKey: 'missing-tone' }, (key) => bundled.get(key)), null);
  assert.equal(sourceForPlayback({ kind: 'bundled', assetKey: 'unknown' }, () => 4), null);
  assert.equal(
    sourceForPlayback({ kind: 'widget', pageUrl: 'https://soundcloud.com/sonicrift/bionic-body' }, () => remote),
    null,
  );
});

test('one rejected add does not abandon the rest of the queue', () => {
  const added: PlaylistAudioSource[] = [];
  const count = addPlaylistSources(
    (source) => {
      if (source.uri.includes('bad')) {
        throw new Error("Calling the 'add' function has failed");
      }
      added.push(source);
    },
    [{ uri: remote }, { uri: 'https://example.com/bad.mp3' }, { uri: 'file:///tone.wav' }],
  );
  assert.equal(count, 2);
  assert.deepEqual(added, [{ uri: remote }, { uri: 'file:///tone.wav' }]);
});

test('lock screen artwork is a URL string or left off', () => {
  assert.deepEqual(
    nowPlayingMetadata({
      title: 'Bionic Body',
      placeholder: false,
      artworkUrl: 'https://i1.sndcdn.com/artworks-example.jpg',
    }),
    {
      title: 'Bionic Body',
      artist: 'sonicrift',
      albumTitle: 'sonicrift',
      artworkUrl: 'https://i1.sndcdn.com/artworks-example.jpg',
    },
  );
  assert.deepEqual(
    nowPlayingMetadata({
      title: 'PLACEHOLDER — rift tone',
      placeholder: true,
      artworkUrl: { href: 'https://i1.sndcdn.com/artworks-example.jpg' },
      fallbackArtworkUrl: undefined,
    }),
    {
      title: 'PLACEHOLDER — rift tone',
      artist: 'sonicrift',
      albumTitle: 'placeholder',
    },
  );
  assert.equal(
    nowPlayingMetadata({
      title: { text: 'nope' },
      placeholder: false,
      artworkUrl: 'not a url',
      fallbackArtworkUrl: 'https://i1.sndcdn.com/avatars.jpg',
    }).title,
    'sonicrift',
  );
  assert.equal(
    nowPlayingMetadata({
      title: 'Space Drift',
      placeholder: false,
      artworkUrl: 'not a url',
      fallbackArtworkUrl: 'https://i1.sndcdn.com/avatars.jpg',
    }).artworkUrl,
    'https://i1.sndcdn.com/avatars.jpg',
  );
});

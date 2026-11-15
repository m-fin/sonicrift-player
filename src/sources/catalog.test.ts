import assert from 'node:assert/strict';
import test from 'node:test';

import { loadCatalog, loadManifestTracks, mergeTracks, type Track } from './catalog';
import sample from './sample-manifest.json' with { type: 'json' };

function track(partial: Partial<Track> & Pick<Track, 'id' | 'title'>): Track {
  return {
    artist: 'sonicrift',
    permalink: partial.permalink ?? `https://soundcloud.com/sonicrift/${partial.id}`,
    sourceId: 'test',
    placeholder: false,
    playback: { kind: 'remote', uri: 'https://example.com/a.mp3' },
    ...partial,
  };
}

test('merge prefers real tracks and drops duplicate permalinks', () => {
  const merged = mergeTracks([
    [
      track({
        id: 'soundcloud:1',
        title: 'Bionic Body',
        releasedAt: '2026-11-01T00:00:00.000Z',
        permalink: 'https://soundcloud.com/sonicrift/bionic-body',
      }),
    ],
    loadManifestTracks(sample),
    [
      track({
        id: 'dup',
        title: 'Bionic Body duplicate',
        permalink: 'https://soundcloud.com/sonicrift/bionic-body',
      }),
    ],
  ]);
  assert.equal(merged[0]?.title, 'Bionic Body');
  assert.equal(merged.filter((item) => item.title.includes('Bionic Body')).length, 1);
  assert.ok(merged.at(-1)?.placeholder);
});

test('catalog loads pluggable sources and marks the new drop', async () => {
  const xml = `<?xml version="1.0"?><rss><channel>
    <item>
      <title>Space Drift</title>
      <link>https://soundcloud.com/sonicrift/space-drift</link>
      <pubDate>Tue, 13 Oct 2026 11:04:41 +0000</pubDate>
      <guid>space</guid>
      <description>Made entirely with code.</description>
      <enclosure url="https://feeds.soundcloud.com/stream/space.mp3" type="audio/mpeg"/>
    </item>
    <item>
      <title>Someone Else - Stolen Loop</title>
      <link>https://soundcloud.com/sonicrift/stolen</link>
      <guid>stolen</guid>
      <description>no copyright infringement intended</description>
      <enclosure url="https://feeds.soundcloud.com/stream/stolen.mp3" type="audio/mpeg"/>
    </item>
  </channel></rss>`;
  const manifestSource = {
    id: 'manifest',
    async load() {
      return loadManifestTracks(sample);
    },
  };
  const catalog = await loadCatalog({
    sources: [manifestSource],
    nowMs: Date.parse('2026-11-14T00:00:00.000Z'),
    fetchText: async (url) => {
      if (url.includes('oembed')) {
        return JSON.stringify({
          title: 'sonicrift',
          author_name: 'sonicrift',
          author_url: 'https://soundcloud.com/sonicrift',
          html: '<iframe src="https://w.soundcloud.com/player/?url=https%3A%2F%2Fapi.soundcloud.com%2Fusers%2F106237603"></iframe>',
        });
      }
      return xml;
    },
  });
  const titles = catalog.tracks.map((item) => item.title);
  assert.ok(titles.includes('Space Drift'));
  assert.equal(titles.some((title) => title.includes('Stolen')), false);
  assert.ok(titles.every((title) => !title.startsWith('PLACEHOLDER') || catalog.tracks.find((item) => item.title === title)?.placeholder));
  assert.deepEqual(catalog.newDropIds, []);
  assert.equal(catalog.profile.author_name, 'sonicrift');
  assert.equal(catalog.errors.length, 0);
});

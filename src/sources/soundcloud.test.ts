import assert from 'node:assert/strict';
import test from 'node:test';

import { isThirdPartyAudio } from '../domain/policy';
import {
  nextRssPage,
  parseSoundCloudRss,
  rssUrlForSoundCloudUser,
  userIdFromWidgetHtml,
} from './soundcloud';

const FIXTURE = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
    <atom:link href="https://feeds.soundcloud.com/users/soundcloud:users:1/sounds.rss?before=9" rel="next" type="application/rss+xml"/>
    <item>
      <title>Bionic Body</title>
      <link>https://soundcloud.com/sonicrift/bionic-body</link>
      <pubDate>Sun, 01 Nov 2026 21:17:25 +0000</pubDate>
      <guid>tag:soundcloud,2010:tracks/100</guid>
      <description>Made entirely with code.</description>
      <enclosure type="audio/mpeg" url="https://feeds.soundcloud.com/stream/100-sonicrift-bionic-body.mp3" length="10"/>
      <itunes:duration>00:01:48</itunes:duration>
      <itunes:image href="https://i1.sndcdn.com/artworks-example.jpg"/>
    </item>
    <item>
      <title>Yeat - Real Geek (prod. Ice Cream) [Slowed Instrumental]</title>
      <link>https://soundcloud.com/sonicrift/yeat-real-geek</link>
      <description>No copyright infringement intended.</description>
      <enclosure url="https://feeds.soundcloud.com/stream/secret-third-party.mp3" type="audio/mpeg"/>
    </item>
  </channel>
</rss>`;

test('parses public feed items and the next page link', () => {
  const tracks = parseSoundCloudRss(FIXTURE);
  assert.equal(tracks.length, 2);
  assert.equal(tracks[0]?.title, 'Bionic Body');
  assert.equal(tracks[0]?.durationMs, 108000);
  assert.equal(tracks[0]?.artworkUrl, 'https://i1.sndcdn.com/artworks-example.jpg');
  assert.equal(tracks[0]?.releasedAt, '2026-11-01T21:17:25.000Z');
  assert.equal(nextRssPage(FIXTURE), 'https://feeds.soundcloud.com/users/soundcloud:users:1/sounds.rss?before=9');
});

test('a catalog built from the feed drops third-party audio', () => {
  const playable = parseSoundCloudRss(FIXTURE).filter((track) => !isThirdPartyAudio(track));
  assert.deepEqual(playable.map((track) => track.title), ['Bionic Body']);
  assert.equal(playable.some((track) => track.streamUrl.includes('third-party')), false);
});

test('oEmbed widget html yields the public RSS url', () => {
  const html =
    '<iframe src="https://w.soundcloud.com/player/?visual=true&url=https%3A%2F%2Fapi.soundcloud.com%2Fusers%2F106237603&show_artwork=true"></iframe>';
  const userId = userIdFromWidgetHtml(html);
  assert.equal(userId, '106237603');
  assert.equal(
    rssUrlForSoundCloudUser(userId ?? ''),
    'https://feeds.soundcloud.com/users/soundcloud:users:106237603/sounds.rss',
  );
});

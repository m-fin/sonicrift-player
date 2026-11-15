export type RssTrack = {
  id: string;
  title: string;
  description: string;
  permalink: string;
  streamUrl: string;
  artworkUrl?: string;
  releasedAt?: string;
  durationMs?: number;
};

const ITEM_PATTERN = /<item\b[^>]*>([\s\S]*?)<\/item>/gi;
const NEXT_PATTERN = /<atom:link\b[^>]*rel=["']next["'][^>]*>/i;
const HREF_PATTERN = /href=["']([^"']+)["']/i;

function decode(value: string): string {
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&apos;/g, "'")
    .trim();
}

function tagText(block: string, tag: string): string {
  const match = block.match(new RegExp(`<${tag}\\b[^>]*>([\\s\\S]*?)</${tag}>`, 'i'));
  return match?.[1] ? decode(match[1]) : '';
}

function attr(block: string, tag: string, name: string): string | undefined {
  const match = block.match(new RegExp(`<${tag}\\b[^>]*>`, 'i'));
  if (!match) return undefined;
  const value = match[0].match(new RegExp(`${name}=["']([^"']+)["']`, 'i'));
  return value?.[1] ? decode(value[1]) : undefined;
}

export function parseRssDuration(value: string | undefined): number | undefined {
  if (!value) return undefined;
  const parts = value.split(':').map((part) => Number(part));
  if (parts.some((part) => !Number.isFinite(part))) return undefined;
  if (parts.length === 3) return ((parts[0] ?? 0) * 3600 + (parts[1] ?? 0) * 60 + (parts[2] ?? 0)) * 1000;
  if (parts.length === 2) return ((parts[0] ?? 0) * 60 + (parts[1] ?? 0)) * 1000;
  if (parts.length === 1) return (parts[0] ?? 0) * 1000;
  return undefined;
}

export function parseSoundCloudRss(xml: string): RssTrack[] {
  const tracks: RssTrack[] = [];
  for (const match of xml.matchAll(ITEM_PATTERN)) {
    const block = match[1] ?? '';
    const title = tagText(block, 'title');
    const permalink = tagText(block, 'link');
    const streamUrl = attr(block, 'enclosure', 'url');
    if (!title || !permalink || !streamUrl) continue;
    const guid = tagText(block, 'guid');
    const id = guid || permalink;
    const pubDate = tagText(block, 'pubDate');
    const released = pubDate ? new Date(pubDate) : undefined;
    tracks.push({
      id,
      title,
      description: tagText(block, 'description') || tagText(block, 'itunes:summary'),
      permalink,
      streamUrl,
      artworkUrl: attr(block, 'itunes:image', 'href'),
      releasedAt: released && !Number.isNaN(released.getTime()) ? released.toISOString() : undefined,
      durationMs: parseRssDuration(tagText(block, 'itunes:duration')),
    });
  }
  return tracks;
}

export function nextRssPage(xml: string): string | null {
  const link = xml.match(NEXT_PATTERN);
  if (!link) return null;
  const href = link[0].match(HREF_PATTERN);
  return href?.[1] ? decode(href[1]) : null;
}

export function userIdFromWidgetHtml(html: string): string | null {
  const encoded = html.match(/api\.soundcloud\.com%2Fusers%2F(\d+)/i);
  if (encoded?.[1]) return encoded[1];
  const plain = html.match(/api\.soundcloud\.com\/users\/(\d+)/i);
  return plain?.[1] ?? null;
}

export function rssUrlForSoundCloudUser(userId: string): string {
  return `https://feeds.soundcloud.com/users/soundcloud:users:${userId}/sounds.rss`;
}

export type OEmbedPayload = {
  title?: string;
  author_name?: string;
  author_url?: string;
  thumbnail_url?: string;
  html?: string;
  description?: string;
};

export function readOEmbed(value: unknown): OEmbedPayload {
  if (!value || typeof value !== 'object') return {};
  const record = value as Record<string, unknown>;
  const pick = (key: string) => (typeof record[key] === 'string' ? record[key] : undefined);
  return {
    title: pick('title'),
    author_name: pick('author_name'),
    author_url: pick('author_url'),
    thumbnail_url: pick('thumbnail_url'),
    html: pick('html'),
    description: pick('description'),
  };
}

export function widgetSrc(pageUrl: string, autoplay = false): string {
  const params = new URLSearchParams({
    url: pageUrl,
    color: 'ff2bd6',
    auto_play: autoplay ? 'true' : 'false',
    hide_related: 'true',
    show_comments: 'false',
    show_user: 'true',
    show_reposts: 'false',
    show_teaser: 'false',
    visual: 'true',
  });
  return `https://w.soundcloud.com/player/?${params.toString()}`;
}

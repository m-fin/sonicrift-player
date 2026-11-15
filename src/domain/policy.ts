const ARTIST_TITLE = /^\s*(?!sonicrift\b)[^:\n]{1,48}?\s[-–—]\s/i;

const THIRD_PARTY_COPY =
  /no copyright infringement|all rights to the original|slowed instrumental of|instrumental of ["“]|cover of|remix of/i;

export function isThirdPartyAudio(input: { title: string; description?: string }): boolean {
  const title = input.title.trim();
  const description = input.description ?? '';
  if (ARTIST_TITLE.test(title)) return true;
  if (THIRD_PARTY_COPY.test(title) || THIRD_PARTY_COPY.test(description)) return true;
  return false;
}

export const NEW_DROP_WINDOW_MS = 21 * 24 * 60 * 60 * 1000;

export type DropCandidate = {
  id: string;
  releasedAt?: string;
  placeholder: boolean;
  newDrop?: boolean;
};

export function selectNewDropIds(tracks: DropCandidate[], nowMs: number): string[] {
  const ranked = tracks
    .filter((track) => !track.placeholder)
    .map((track) => {
      const releasedMs = track.releasedAt ? Date.parse(track.releasedAt) : Number.NaN;
      const flagged = track.newDrop === true;
      const recent = Number.isFinite(releasedMs) && nowMs - releasedMs <= NEW_DROP_WINDOW_MS && releasedMs <= nowMs;
      return { id: track.id, releasedMs, include: flagged || recent };
    })
    .filter((track) => track.include)
    .sort((a, b) => (b.releasedMs || 0) - (a.releasedMs || 0));
  return ranked.map((track) => track.id);
}

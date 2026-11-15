function clampRatio(ratio: number): number | null {
  if (!Number.isFinite(ratio)) return null;
  return Math.min(1, Math.max(0, ratio));
}

/** Turns a press into a 0–1 position. Web presses sometimes omit locationX. */
export function seekRatio(input: {
  locationX?: number;
  width: number;
  pageX?: number;
  originX?: number;
  originWidth?: number;
}): number | null {
  if (Number.isFinite(input.locationX) && input.width > 0) {
    return clampRatio((input.locationX as number) / input.width);
  }
  if (
    Number.isFinite(input.pageX) &&
    Number.isFinite(input.originX) &&
    input.originWidth != null &&
    input.originWidth > 0
  ) {
    return clampRatio(((input.pageX as number) - (input.originX as number)) / input.originWidth);
  }
  return null;
}

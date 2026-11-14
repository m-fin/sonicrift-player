export const brand = {
  bg: '#07060D',
  bgRaised: '#120F1C',
  bgCard: '#181428',
  line: 'rgba(255, 43, 214, 0.45)',
  lineSoft: 'rgba(61, 255, 242, 0.22)',
  magenta: '#FF2BD6',
  cyan: '#3DFFF2',
  violet: '#8D6BFF',
  text: '#F6F3FF',
  muted: '#A79FBE',
  dim: '#6E6784',
  danger: '#FF5C8A',
} as const;

export const font = {
  display: 'Syne_800ExtraBold',
  displayBold: 'Syne_700Bold',
  body: 'Manrope_500Medium',
  bodyBold: 'Manrope_700Bold',
} as const;

export function formatClock(seconds: number): string {
  if (!Number.isFinite(seconds) || seconds < 0) return '0:00';
  const total = Math.floor(seconds);
  const minutes = Math.floor(total / 60);
  const remain = total % 60;
  return `${minutes}:${remain.toString().padStart(2, '0')}`;
}

export function formatDuration(ms?: number): string {
  if (!ms || ms <= 0) return '—';
  return formatClock(ms / 1000);
}

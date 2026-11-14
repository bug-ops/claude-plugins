export function chunk<T>(items: readonly T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i + size <= items.length; i += size) {
    out.push(items.slice(i, i + size));
  }
  return out;
}

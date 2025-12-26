/**
 * Helpers to normalize genres for backend searches.
 * - Accepts a string (comma-separated) or array of strings
 * - Trims whitespace, lowercases, removes empty entries and duplicates
 */
export function normalizeGenres(input?: string | string[]): string[] {
  if (!input) return [];

  const raw: string[] = Array.isArray(input) ? input : String(input).split(',');
  const seen = new Set<string>();
  const out: string[] = [];

  for (let item of raw) {
    if (item == null) continue;
    item = String(item).trim();
    if (!item) continue;
    const lower = item.toLowerCase();
    if (!seen.has(lower)) {
      seen.add(lower);
      out.push(lower);
    }
  }

  return out;
}

/**
 * Build LIKE parameters for TypeORM queries when searching by genre names.
 * Example usage:
 * const genres = normalizeGenres(req.query.genres);
 * const conditions = genres.map((_, i) => `LOWER(song.genres) LIKE :g${i}` ).join(' OR ');
 * genres.forEach((g, i) => qb.setParameter(`g${i}`, `%${g}%`));
 */
export function buildLikeParams(genres: string[]): { [key: string]: string } {
  const params: { [key: string]: string } = {};
  genres.forEach((g, i) => {
    params[`g${i}`] = `%${g}%`;
  });
  return params;
}

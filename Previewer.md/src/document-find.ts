export type FindMatch = {
  start: number;
  end: number;
};

export function findMarkdownMatches(markdown: string, query: string): FindMatch[] {
  const needle = query.trim().toLocaleLowerCase();
  if (!needle) {
    return [];
  }

  const haystack = markdown.toLocaleLowerCase();
  const matches: FindMatch[] = [];
  let start = 0;

  while (start < haystack.length) {
    const index = haystack.indexOf(needle, start);
    if (index === -1) {
      break;
    }

    matches.push({ start: index, end: index + needle.length });
    start = index + needle.length;
  }

  return matches;
}

export function getNextFindMatchIndex(currentIndex: number, matchCount: number, direction: 1 | -1) {
  if (matchCount === 0) {
    return -1;
  }

  if (currentIndex < 0) {
    return direction === 1 ? 0 : matchCount - 1;
  }

  return (currentIndex + direction + matchCount) % matchCount;
}

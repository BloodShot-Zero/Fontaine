/* Server URL adapter for the anime and movie/TV player selectors. */
window.fontaineAlternateStreamURL = function (title) {
  const server = document.getElementById('xserver')?.value || 'furina';
  if (server !== 'phrolova') return null;

  if (title.kind === 'anime') {
    const animeId = title.anilistId || String(title.id).replace(/^a/, '');
    const episode = Math.max(1, parseInt(document.getElementById('xepisode')?.value, 10) || 1);
    const language = document.getElementById('xlang')?.value === 'dub' ? 'dub' : 'sub';
    return `https://kuroko.cc/embed/ani/${encodeURIComponent(animeId)}/${episode}/${language}?autoplay=1`;
  }

  if (title.kind === 'movie' && title.tmdb) {
    return `https://atlantic.st/embed/movie/${encodeURIComponent(title.tmdb)}`;
  }

  if (title.kind === 'tv' && title.tmdb) {
    const season = Math.max(0, parseInt(document.getElementById('xseason')?.value, 10) || 1);
    const episode = Math.max(1, parseInt(document.getElementById('xepisode')?.value, 10) || 1);
    return `https://atlantic.st/embed/tv/${encodeURIComponent(title.tmdb)}/${season}/${episode}`;
  }

  return null;
};

'use strict';
// Preserve supplemental URLs shared from the first edition.
(async () => {
  const file = new URLSearchParams(location.search).get('file');
  if (!file) { location.replace('reading.html'); return; }
  try {
    const response = await fetch('reference-manifest.json');
    if (!response.ok) throw new Error('The reading index could not be loaded.');
    const manifest = await response.json();
    if (!Object.hasOwn(manifest.pages, file)) throw new Error('This file is not in the reading library. Choose a document below.');
    location.replace(manifest.pages[file] + location.hash);
  } catch (error) { document.querySelector('#reference-status').textContent = error.message; }
})();

'use strict';
(() => {
  const script = document.querySelector('script[src$="site.js"]');
  const base = new URL('.', script.src);
  const navButton = document.querySelector('[data-nav-toggle]');
  const sidebar = document.querySelector('.docs-sidebar');
  const scrim = document.querySelector('[data-nav-close]');
  function closeNav() { document.body.classList.remove('nav-open'); navButton?.setAttribute('aria-expanded', 'false'); if (scrim) scrim.hidden = true; }
  navButton?.addEventListener('click', () => { const open = !document.body.classList.contains('nav-open'); document.body.classList.toggle('nav-open', open); navButton.setAttribute('aria-expanded', String(open)); scrim.hidden = !open; });
  scrim?.addEventListener('click', closeNav);
  sidebar?.addEventListener('click', event => { if (event.target.closest('a')) closeNav(); });
  addEventListener('keydown', event => { if (event.key === 'Escape') closeNav(); });

  const dialog = document.createElement('dialog');
  dialog.className = 'search-dialog';
  dialog.setAttribute('aria-label', 'Search documentation');
  dialog.innerHTML = '<div class="search-input-row"><svg width="19" height="19" viewBox="0 0 20 20" fill="none" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5" stroke="currentColor" stroke-width="1.5"/><path d="m13 13 4 4" stroke="currentColor" stroke-width="1.5"/></svg><input id="docs-search-input" type="search" placeholder="Search documentation…" autocomplete="off" aria-label="Search documentation" aria-controls="docs-search-results"><button type="button" aria-label="Close search">Esc</button></div><div class="search-results" id="docs-search-results" role="list"></div><div class="search-help"><span>↑ ↓ to select</span><span>↵ to open</span><a href="'+new URL('reading.html',base).href+'">Browse all docs →</a></div>';
  document.body.append(dialog);
  const input = dialog.querySelector('input');
  const results = dialog.querySelector('.search-results');
  let records, loading, selected = 0, lastFocus;
  async function loadIndex() {
    if (records) return records;
    if (!loading) loading = fetch(new URL('search-index.json', base)).then(response => { if (!response.ok) throw new Error('Search is unavailable. Browse the documentation library below.'); return response.json(); });
    records = await loading; return records;
  }
  function render() {
    if (!records) return;
    const terms = input.value.toLowerCase().trim().split(/\s+/).filter(Boolean);
    const matches = records.filter(record => terms.every(term => record.search.includes(term))).map(record => ({ ...record, score: terms.reduce((total, term) => total + (record.title.toLowerCase().includes(term) ? 5 : 0), 0) + (record.primary ? 2 : 0) })).sort((a,b) => b.score-a.score).slice(0,18);
    results.replaceChildren(); selected = 0;
    if (!matches.length) { const message = document.createElement('p'); message.className = 'search-empty'; message.textContent = 'No results. Try a shorter term or a framework name.'; results.append(message); }
    for (const record of matches) {
      const link = document.createElement('a'); link.href = new URL(record.path, base).href; link.className = 'search-result'; link.setAttribute('role','listitem');
      const label = document.createElement('small'); label.textContent = record.category;
      const title = document.createElement('strong'); title.textContent = record.title;
      const description = document.createElement('span'); description.textContent = record.description || record.file;
      link.append(label,title,description); results.append(link);
    }
    markSelected();
  }
  function markSelected() { [...results.querySelectorAll('a')].forEach((link,index) => { link.classList.toggle('selected',index===selected); if(index===selected) link.scrollIntoView({block:'nearest'}); }); }
  async function openSearch() {
    lastFocus = document.activeElement; closeNav(); dialog.showModal(); input.focus();
    results.textContent = 'Loading documentation…';
    try { await loadIndex(); render(); } catch(error) { results.textContent = error.message; }
  }
  document.querySelectorAll('[data-search-open]').forEach(button => button.addEventListener('click',openSearch));
  dialog.querySelector('button').addEventListener('click',()=>dialog.close());
  dialog.addEventListener('close',()=>lastFocus?.focus());
  dialog.addEventListener('click',event=>{ if(event.target===dialog) dialog.close(); });
  input.addEventListener('input',render);
  input.addEventListener('keydown',event=>{
    const links=[...results.querySelectorAll('a')];
    if(event.key==='ArrowDown' && links.length){event.preventDefault();selected=(selected+1)%links.length;markSelected();}
    if(event.key==='ArrowUp' && links.length){event.preventDefault();selected=(selected+links.length-1)%links.length;markSelected();}
    if(event.key==='Enter' && links[selected]){event.preventDefault();location.href=links[selected].href;}
  });
  addEventListener('keydown',event=>{if((event.metaKey||event.ctrlKey)&&event.key.toLowerCase()==='k'){event.preventDefault();if(dialog.open)dialog.close();else openSearch();}});
})();

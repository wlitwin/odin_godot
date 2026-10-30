'use strict';
const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
let toastTimer;
function toast(text) { const node = $('#toast'); if (!node) return; node.textContent = text; node.classList.add('visible'); clearTimeout(toastTimer); toastTimer = setTimeout(() => node.classList.remove('visible'), 1800); }
document.addEventListener('click', async event => {
  const button = event.target.closest('.copy-code');
  if (!button) return;
  const pre = button.closest('.code-block').querySelector('pre');
  try { await navigator.clipboard.writeText(pre.textContent); toast('Copied to clipboard'); }
  catch { const range = document.createRange(); range.selectNodeContents(pre); const selection = getSelection(); selection.removeAllRanges(); selection.addRange(range); toast('Code selected. Copy with your keyboard.'); }
});
$$('[data-print]').forEach(button => button.addEventListener('click', () => print()));
const sections = $$('.reading-body h2[id], .reading-body h3[id]');
if (sections.length && 'IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries => entries.forEach(entry => {
    if (!entry.isIntersecting) return;
    $$('.page-outline nav a').forEach(link => { const active = decodeURIComponent(link.hash.slice(1)) === entry.target.id; link.classList.toggle('active', active); if (active) link.setAttribute('aria-current', 'location'); else link.removeAttribute('aria-current'); });
  }), { rootMargin: '-5% 0px -65% 0px', threshold: 0 });
  sections.forEach(section => observer.observe(section));
}
const progress = $('#reading-progress');
if (progress) {
  const update = () => { const height = document.documentElement.scrollHeight - innerHeight; progress.style.width = `${height > 0 ? Math.min(100, scrollY / height * 100) : 100}%`; };
  addEventListener('scroll', update, { passive: true }); addEventListener('resize', update); update();
}
$$('.mobile-toc a').forEach(link => link.addEventListener('click', () => { $('.mobile-toc').open = false; }));
const search = $('#library-search');
if (search) {
  const all = $$('.library-item');
  search.addEventListener('input', () => {
    const terms = search.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
    let count = 0;
    all.forEach(item => { item.hidden = !terms.every(term => item.dataset.search.includes(term)); if (!item.hidden) count++; });
    $$('.library-group').forEach(group => { group.hidden = ![...group.querySelectorAll('.library-item')].some(item => !item.hidden); });
    $('.library-all').open = terms.length > 0;
    $('#library-count').textContent = `${count} ${count === 1 ? 'document' : 'documents and source examples'}${terms.length ? ' found' : ''}`;
    $('#library-empty').hidden = count > 0;
  });
}

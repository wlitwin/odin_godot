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
  const countLabel = $('#library-count');
  const summary = countLabel.dataset.summary || countLabel.textContent;
  const legacyGroup = $('.library-all');
  if (legacyGroup) legacyGroup.open = true;
  search.addEventListener('input', () => {
    const terms = search.value.trim().toLowerCase().split(/\s+/).filter(Boolean);
    let count = 0;
    all.forEach(item => { item.hidden = !terms.every(term => item.dataset.search.includes(term)); if (!item.hidden) count++; });
    $$('.library-group').forEach(group => { group.hidden = ![...group.querySelectorAll('.library-item')].some(item => !item.hidden); });
    $$('[data-index-subgroup]').forEach(group => {
      const visible = [...group.querySelectorAll('.library-item')].filter(item => !item.hidden).length;
      group.hidden = visible === 0;
      const label = group.querySelector('[data-subgroup-count]');
      if (label) label.textContent = visible;
    });
    $$('[data-index-section]').forEach(section => {
      const visible = [...section.querySelectorAll('.library-item')].filter(item => !item.hidden).length;
      section.hidden = visible === 0;
      section.querySelector('[data-section-count]').textContent = visible;
      const topic = document.querySelector(`[data-index-target="${section.id}"]`);
      if (topic) { topic.hidden = visible === 0; topic.querySelector('[data-topic-count]').textContent = visible; }
    });
    countLabel.textContent = terms.length ? `${count} of ${all.length} pages match` : summary;
    $('#library-empty').hidden = count > 0;
  });
}

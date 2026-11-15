<script setup>
import { computed, ref } from 'vue'
import { withBase } from 'vitepress'
import declarations from '../cache/api/search.json'

const query = ref('')
const kind = ref('All declarations')
const categories = ['All declarations', 'Types', 'Functions', 'Aliases', 'Constants and variables']
const results = computed(() => {
  const words = query.value.trim().toLowerCase().split(/\s+/).filter(Boolean)
  if (!words.length) return []
  return declarations.filter((entry) => {
    if (kind.value !== categories[0] && entry.kind !== kind.value) return false
    const text = `${entry.package} ${entry.name} ${entry.summary}`.toLowerCase()
    return words.every((word) => text.includes(word))
  }).sort((a, b) => {
    const value = query.value.trim().toLowerCase()
    const rank = (entry) => entry.name.toLowerCase() === value ? 0 : entry.name.toLowerCase().startsWith(value) ? 1 : 2
    return rank(a) - rank(b) || a.name.localeCompare(b.name) || a.package.localeCompare(b.package)
  })
})
</script>

<template>
  <section class="api-search" aria-label="Search API declarations">
    <label for="api-query">Find a type, function, or constant</label>
    <div class="api-search-controls">
      <input id="api-query" v-model="query" type="search" autocomplete="off"
        placeholder="world_step_fixed, Session, subscribe…" aria-controls="api-results" />
      <select v-model="kind" aria-label="Declaration kind">
        <option v-for="category in categories" :key="category">{{ category }}</option>
      </select>
    </div>
    <template v-if="query.trim()">
      <p role="status">{{ results.length }} matching declarations<span v-if="results.length > 40">; showing the first 40. Add a package name to narrow the search.</span></p>
      <ul id="api-results" class="api-results">
        <li v-for="entry in results.slice(0, 40)" :key="entry.url">
          <a :href="withBase(entry.url)"><code>{{ entry.name }}</code></a>
          <span class="api-result-package">{{ entry.package }} · {{ entry.kind }}</span>
          <p v-if="entry.summary">{{ entry.summary }}</p>
        </li>
      </ul>
    </template>
  </section>
</template>

<style scoped>
.api-search { margin: 24px 0 32px; padding: 20px; border: 1px solid var(--vp-c-divider); border-radius: 8px; }
label { display: block; margin-bottom: 10px; font-weight: 600; }
.api-search-controls { display: flex; gap: 10px; }
input, select { border: 1px solid var(--vp-c-divider); border-radius: 6px; background: var(--vp-c-bg); color: var(--vp-c-text-1); padding: 10px 12px; font: inherit; }
input { flex: 1; min-width: 0; }
input:focus-visible, select:focus-visible { outline: 2px solid var(--vp-c-brand-1); outline-offset: 2px; }
.api-results { margin: 12px 0 0; padding: 0; list-style: none; }
.api-results li { padding: 12px 0; border-top: 1px solid var(--vp-c-divider); }
.api-results li:last-child { padding-bottom: 0; }
.api-result-package { display: block; font-size: 12px; color: var(--vp-c-text-2); }
.api-results p { margin: 4px 0 0; font-size: 14px; line-height: 1.6; }
@media (max-width: 640px) { .api-search-controls { flex-direction: column; } }
</style>

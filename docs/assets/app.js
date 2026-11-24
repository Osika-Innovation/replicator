(() => {
  'use strict';
  document.documentElement.classList.add('js');
  const root = new URL(document.body.dataset.root || './', document.baseURI);
  const input = document.getElementById('site-search');
  const panel = document.getElementById('search-panel');
  const results = document.getElementById('search-results');
  const status = document.getElementById('search-status');
  const toggle = document.querySelector('.menu-toggle');
  let entries = null;
  let loading = null;
  let searchVersion = 0;

  function setMenu(open) {
    document.documentElement.classList.toggle('menu-open', open);
    if (toggle) {
      toggle.setAttribute('aria-expanded', String(open));
      toggle.setAttribute('aria-label', open ? 'Close navigation' : 'Open navigation');
    }
  }
  if (toggle) toggle.addEventListener('click', () => setMenu(toggle.getAttribute('aria-expanded') !== 'true'));
  document.querySelectorAll('#sidebar a').forEach(link => link.addEventListener('click', () => setMenu(false)));
  if (!input || !panel || !results || !status) return;

  function showPanel(open) {
    panel.hidden = !open;
    input.setAttribute('aria-expanded', String(open));
  }
  function clean(value) { return String(value || '').toLowerCase().normalize('NFKD').replace(/[\u0300-\u036f]/g, ''); }
  async function loadIndex() {
    if (entries) return entries;
    if (!loading) {
      loading = fetch(new URL('document-index.json', root)).then(response => {
        if (!response.ok) throw new Error('Search index unavailable');
        return response.json();
      }).then(data => {
        const records = Array.isArray(data) ? data : data.documents;
        if (!Array.isArray(records)) throw new Error('Invalid search index');
        entries = records.map(item => ({...item, _title: clean(item.title), _summary: clean(item.summary), _topics: clean(Array.isArray(item.topics) ? item.topics.join(' ') : item.topics), _text: clean(item.text)}));
        return entries;
      }).catch(error => { loading = null; throw error; });
    }
    return loading;
  }
  function score(item, terms) {
    let points = 0;
    for (const term of terms) {
      const title = item._title.includes(term), topics = item._topics.includes(term), summary = item._summary.includes(term), body = item._text.includes(term);
      if (!title && !topics && !summary && !body) return 0;
      points += (title ? 12 : 0) + (topics ? 7 : 0) + (summary ? 4 : 0) + (body ? 1 : 0);
    }
    if (item.type === 'guide') points += 2;
    return points;
  }
  function addResult(item) {
    let url;
    try { url = new URL(item.url, root); } catch (_) { return; }
    if (!['http:', 'https:', 'file:'].includes(url.protocol)) return;
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.className = 'search-result';
    a.href = url.href;
    const title = document.createElement('strong'); title.textContent = item.title || item.id;
    const summary = document.createElement('p'); summary.textContent = item.summary || '';
    const meta = document.createElement('small'); meta.textContent = [item.type, item.status].filter(Boolean).join(' · ');
    a.append(title, summary, meta); li.append(a); results.append(li);
  }
  async function search() {
    const version = ++searchVersion;
    const query = clean(input.value.trim());
    results.replaceChildren();
    showPanel(true);
    status.textContent = query ? 'Searching…' : 'Search architecture, subsystems, papers and agent instructions.';
    try {
      const data = await loadIndex();
      if (version !== searchVersion) return;
      if (!query) return;
      const terms = query.split(/\s+/).filter(Boolean);
      const matches = data.map(item => ({item, score: score(item, terms)})).filter(match => match.score > 0).sort((a, b) => b.score - a.score || a.item.title.localeCompare(b.item.title));
      status.textContent = matches.length ? `${matches.length} result${matches.length === 1 ? '' : 's'}${matches.length > 12 ? ' · showing the first 12' : ''}` : 'No matches. Try a subsystem, a material or a shorter phrase.';
      matches.slice(0, 12).forEach(match => addResult(match.item));
    } catch (_) {
      if (version !== searchVersion) return;
      status.textContent = 'Search is unavailable. Use the navigation to browse every section.';
    }
  }
  input.addEventListener('focus', search);
  input.addEventListener('input', search);
  input.addEventListener('keydown', event => {
    if (event.key === 'ArrowDown') {
      const first = results.querySelector('a');
      if (first) { event.preventDefault(); first.focus(); }
    }
    if (event.key === 'Enter') {
      const first = results.querySelector('a');
      if (first) { event.preventDefault(); first.click(); }
    }
  });
  document.addEventListener('keydown', event => {
    const editing = event.target instanceof HTMLElement && (event.target.matches('input, textarea, select') || event.target.isContentEditable);
    if (event.key === '/' && !editing && !event.ctrlKey && !event.metaKey && !event.altKey) { event.preventDefault(); input.focus(); }
    if (event.key === 'Escape') {
      if (panel.contains(document.activeElement)) input.focus();
      ++searchVersion;
      showPanel(false);
      setMenu(false);
    }
  });
  document.addEventListener('click', event => { if (!event.target.closest('.search-wrap')) { ++searchVersion; showPanel(false); } });
})();

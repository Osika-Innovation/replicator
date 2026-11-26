// Interactive 3D viewer for the Desktop Replicator CAD model.
// Model data: assets/cad/desktop.json + desktop.bin, made by tools/build_cad_model.py.
// Needs the import map on the page (three and three/addons). If that fails to load,
// the static render inside the container stays visible.
const root = document.getElementById('cad-viewer');
if (root) start(root).catch((err) => fail(root, err));

function fail(el, err) {
  console.error(err);
  el.classList.add('cad-failed');
  const note = el.querySelector('.cad-note');
  if (note) note.textContent = 'The 3D viewer could not start in this browser. The picture above is a render of the same model.';
}

async function start(el) {
  const THREE = await import('three');
  const { OrbitControls } = await import('three/addons/controls/OrbitControls.js');
  const base = el.dataset.model;
  const [meta, buf] = await Promise.all([
    fetch(base + '.json').then((r) => r.json()),
    fetch(base + '.bin').then((r) => r.arrayBuffer()),
  ]);

  // Module map (M01-M08). modules.json is the handbook's text for each module; module_manifest.json is the
  // engineering export (task #132). Either may be missing or slow: parts already carry a module tag baked in at
  // build time, so the pills work offline and the manifest only refines them when it arrives and is readable.
  const dir = base.slice(0, base.lastIndexOf('/') + 1);
  const modsInfo = await fetch(el.dataset.modules || dir + 'modules.json').then((r) => (r.ok ? r.json() : null)).catch(() => null);
  const manifest = await Promise.race([
    fetch(dir + 'module_manifest.json').then((r) => (r.ok ? r.json() : null)).catch(() => null),
    new Promise((res) => setTimeout(() => res(null), 2500)),
  ]);
  const modById = Object.fromEntries(((modsInfo && modsInfo.modules) || []).map((m) => [m.id, m]));
  const modOf = new Map();
  let modSource = 'handbook rules';
  for (const p of meta.parts) modOf.set(p.id, p.module || null);
  if (manifest) {
    // Accepts {modules:[{id, parts|objects|groups|members:[names or prefixes]}]}, {modules:{M01:[...]}}, or {M01:[...]}.
    const raw = manifest.modules || manifest;
    const list = Array.isArray(raw) ? raw.map((m) => [m.id || m.module, m.parts || m.objects || m.groups || m.members || m.prefixes || []])
      : Object.entries(raw).filter(([k]) => /^M0[1-8]$/.test(k)).map(([k, v]) => [k, Array.isArray(v) ? v : (v.parts || v.objects || v.groups || v.members || [])]);
    let hit = 0;
    for (const [id, names] of list) {
      if (!/^M0[1-8]$/.test(id || '')) continue;
      for (const s of names) {
        const key = String(s).toLowerCase();
        for (const p of meta.parts) {
          if (p.id.toLowerCase() === key || p.id.toLowerCase().startsWith(key) || p.name.toLowerCase() === key) { modOf.set(p.id, id); hit++; }
        }
      }
    }
    if (hit) modSource = 'engineering manifest';
  }

  const stage = el.querySelector('.cad-stage');
  const tip = el.querySelector('.cad-tip');
  const panel = el.querySelector('.cad-panel');
  const legend = el.querySelector('.cad-legend');
  const explode = el.querySelector('#cad-explode');
  const cut = el.querySelector('#cad-cut');
  const glassBox = el.querySelector('#cad-glass');

  // Model frame is z up and front at +x; three.js is y up. (x, y, z) -> (x, z, -y).
  const nv = meta.counts.vertices;
  const src = new Float32Array(buf, 0, nv * 3);
  const pos = new Float32Array(nv * 3);
  for (let i = 0; i < nv; i++) {
    pos[3 * i] = src[3 * i];
    pos[3 * i + 1] = src[3 * i + 2];
    pos[3 * i + 2] = -src[3 * i + 1];
  }
  const idx = new Uint32Array(buf, nv * 12, meta.counts.indices);
  const posAttr = new THREE.BufferAttribute(pos, 3);

  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0xf4f6f1);
  const renderer = new THREE.WebGLRenderer({ antialias: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  renderer.localClippingEnabled = true;
  stage.appendChild(renderer.domElement);

  const camera = new THREE.PerspectiveCamera(32, 1, 20, 8000);
  const [x0, y0, z0, x1, y1, z1] = meta.bounds;
  const centre = new THREE.Vector3((x0 + x1) / 2, (z0 + z1) / 2, -(y0 + y1) / 2);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.target.copy(centre);
  const VIEWS = {
    iso: [1250, 560, 1000], front: [1900, 330, 0], rear: [-1900, 330, 0], top: [1, 2200, 1], side: [0, 330, 1900],
  };
  const go = (name) => {
    const v = VIEWS[name];
    camera.position.set(centre.x + v[0], centre.y + v[1], centre.z + v[2]);
    controls.target.set(centre.x, centre.y + shift, centre.z);
    camera.position.y += shift;
    controls.update();
    dirty = true;
  };

  scene.add(new THREE.HemisphereLight(0xffffff, 0x9aa59a, 1.15));
  const sun = new THREE.DirectionalLight(0xffffff, 1.6);
  sun.position.set(900, 1400, 700);
  scene.add(sun);
  const fill = new THREE.DirectionalLight(0xdfe9ff, 0.7);
  fill.position.set(-900, 500, -800);
  scene.add(fill);

  const clip = new THREE.Plane(new THREE.Vector3(0, 0, 1), 9999);
  const asmById = Object.fromEntries(meta.assemblies.map((a) => [a.id, a]));
  const group = new THREE.Group();
  scene.add(group);

  const entries = [];
  for (const p of meta.parts) {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', posAttr);
    geo.setIndex(new THREE.BufferAttribute(idx.subarray(p.tri[0] * 3, (p.tri[0] + p.tri[1]) * 3), 1));
    const [a, b, c, d, e, f] = p.bbox;
    geo.boundingBox = new THREE.Box3(new THREE.Vector3(a, c, -e), new THREE.Vector3(d, f, -b));
    geo.boundingSphere = new THREE.Sphere();
    geo.boundingBox.getBoundingSphere(geo.boundingSphere);
    const m = meta.materials[p.matKey] || { color: [0.5, 0.5, 0.5], opacity: 1 };
    const mat = new THREE.MeshStandardMaterial({
      color: new THREE.Color(m.color[0], m.color[1], m.color[2]), roughness: 0.62, metalness: m.opacity < 1 ? 0 : 0.18,
      flatShading: true, side: THREE.DoubleSide, transparent: m.opacity < 1, opacity: m.opacity,
      depthWrite: m.opacity >= 1, clippingPlanes: [clip], emissive: 0x000000,
    });
    const mesh = new THREE.Mesh(geo, mat);
    mesh.userData = { part: p, glass: m.opacity < 0.5, home: new THREE.Vector3() };
    group.add(mesh);
    entries.push(mesh);
  }

  let dirty = true;
  let t = 0, tTarget = 0;
  let shift = 0;
  let hover = null, selected = null, isolated = null, isoModule = null;
  const hidden = new Set();

  function layout() {
    for (const m of entries) {
      const [dx, dz] = asmById[m.userData.part.assembly].explode;
      m.position.set(dx * t, dz * t, 0);
    }
    // Keep the whole stack in frame: zoom out and lift the view as the parts separate.
    const lift = 330 * t - shift;
    shift += lift;
    camera.position.y += lift;
    controls.target.y += lift;
    camera.zoom = 1 / (1 + 1.1 * t);
    camera.updateProjectionMatrix();
    dirty = true;
  }
  function visibility() {
    for (const m of entries) {
      const a = m.userData.part.assembly;
      const ghost = (isolated && a !== isolated) || (isoModule && modOf.get(m.userData.part.id) !== isoModule);
      m.visible = !hidden.has(a) && !(m.userData.glass && !glassBox.checked);
      m.material.opacity = ghost ? 0.08 : (m.userData.glass ? meta.materials[m.userData.part.matKey].opacity : 1);
      m.material.transparent = ghost || m.userData.glass;
      m.material.depthWrite = !(ghost || m.userData.glass);
    }
    dirty = true;
  }
  function paint() {
    for (const m of entries) {
      const on = m === selected ? 0x2a8f7f : m === hover ? 0x1b5f55 : 0x000000;
      m.material.emissive.setHex(on);
      m.material.emissiveIntensity = m === selected ? 0.75 : 0.5;
    }
    dirty = true;
  }

  const ray = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  function pick(ev) {
    const r = renderer.domElement.getBoundingClientRect();
    ndc.set(((ev.clientX - r.left) / r.width) * 2 - 1, -((ev.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    const hits = ray.intersectObjects(entries.filter((m) => m.visible), false)
      .filter((h) => clip.distanceToPoint(h.point) >= 0);
    return (hits.find((h) => !h.object.userData.glass) || hits[0] || {}).object || null;
  }
  const size = (p) => [p.bbox[3] - p.bbox[0], p.bbox[4] - p.bbox[1], p.bbox[5] - p.bbox[2]].map((v) => Math.round(v * 10) / 10).join(' × ');

  renderer.domElement.addEventListener('pointermove', (ev) => {
    if (ev.buttons) { tip.hidden = true; return; }
    const m = pick(ev);
    if (m !== hover) { hover = m; paint(); }
    if (!m) { tip.hidden = true; renderer.domElement.style.cursor = 'grab'; return; }
    const p = m.userData.part;
    tip.hidden = false;
    const mid = modOf.get(p.id);
    tip.replaceChildren(el2('strong', p.name), el2('span', (mid ? mid + ' · ' : '') + asmById[p.assembly].title), el2('small', `${p.material} · ${size(p)} mm`));
    const r = stage.getBoundingClientRect();
    tip.style.left = Math.min(ev.clientX - r.left + 14, r.width - 230) + 'px';
    tip.style.top = Math.min(ev.clientY - r.top + 14, r.height - 80) + 'px';
    renderer.domElement.style.cursor = 'pointer';
  });
  renderer.domElement.addEventListener('pointerleave', () => { hover = null; tip.hidden = true; paint(); });
  let down = null;
  renderer.domElement.addEventListener('pointerdown', (ev) => { down = [ev.clientX, ev.clientY]; });
  renderer.domElement.addEventListener('pointerup', (ev) => {
    if (!down || Math.hypot(ev.clientX - down[0], ev.clientY - down[1]) > 5) return;
    select(pick(ev));
  });

  function el2(tag, text, attrs) {
    const n = document.createElement(tag);
    if (text != null) n.textContent = text;
    for (const k in attrs || {}) n.setAttribute(k, attrs[k]);
    return n;
  }
  function link(href, label) { return el2('a', label + ' →', { href, class: 'cad-link' }); }

  function select(m) {
    selected = m;
    paint();
    panel.replaceChildren();
    if (!m) {
      panel.append(el2('p', 'Click a part, or choose an assembly in the list. Drag to turn the model, scroll to zoom.', { class: 'cad-hint' }));
      return;
    }
    const p = m.userData.part, a = asmById[p.assembly];
    panel.append(
      el2('span', (modOf.get(p.id) ? modOf.get(p.id) + ' · ' : '') + a.title, { class: 'eyebrow' }),
      el2('h3', p.name),
      el2('p', p.text || a.summary),
      el2('p', `${p.material} · ${size(p)} mm (bounding box, from the CAD model)`, { class: 'cad-meta' }),
      el2('div', null, { class: 'cad-links' }),
    );
    const box = panel.querySelector('.cad-links');
    box.append(link(p.subsystem, p.subsystemLabel), link(p.guide, p.guideLabel));
    const iso = el2('button', isolated === p.assembly ? 'Show all assemblies' : 'Isolate this assembly', { type: 'button', class: 'cad-btn' });
    iso.addEventListener('click', () => isolate(p.assembly));
    panel.append(iso);
  }
  function isolate(id) {
    isolated = isolated === id ? null : id;
    visibility();
    legend.querySelectorAll('button[data-asm]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.asm === isolated)));
    if (selected) select(selected);
  }

  // Assembly list
  for (const a of meta.assemblies) {
    const li = el2('li');
    const vis = el2('input', null, { type: 'checkbox', checked: '', 'aria-label': 'Show ' + a.title });
    vis.addEventListener('change', () => { vis.checked ? hidden.delete(a.id) : hidden.add(a.id); visibility(); });
    const b = el2('button', a.title, { type: 'button', 'data-asm': a.id, 'aria-pressed': 'false' });
    b.addEventListener('click', () => {
      isolate(a.id);
      panel.replaceChildren(el2('span', 'Assembly', { class: 'eyebrow' }), el2('h3', a.title), el2('p', a.summary),
        el2('p', `${meta.parts.filter((p) => p.assembly === a.id).length} parts`, { class: 'cad-meta' }), el2('div', null, { class: 'cad-links' }));
      panel.querySelector('.cad-links').append(link(a.subsystem, a.subsystemLabel), link(a.guide, a.guideLabel));
    });
    li.append(vis, b);
    legend.append(li);
  }

  // Module pills: All, M01-M08
  const MOD_COLOR = { M01: '#186b60', M02: '#9a542e', M03: '#2f5aa0', M04: '#7a4f9a', M05: '#8f6d10', M06: '#3f7a28', M07: '#55616b', M08: '#a83f3f' };
  const BADGE = { derived: ['Derived', 'bd-derived'], simulated: ['Simulated', 'bd-sim'], documented: ['Documented', 'bd-doc'],
    decision: ['Design decision', 'bd-dec'], open: ['Open', 'bd-open'], claim: ['Claim', 'bd-claim'] };
  const bar = el.querySelector('.cad-bar');
  const modBar = el2('div', null, { class: 'cad-mods', role: 'group', 'aria-label': 'Isolate a module' });
  modBar.append(el2('span', 'Module', { class: 'eyebrow' }));
  const pills = [];
  const counts = {};
  for (const id of modOf.values()) counts[id] = (counts[id] || 0) + 1;
  const mkPill = (id, label) => {
    const b = el2('button', label, { type: 'button', class: 'cad-pill', 'data-mod': id, 'aria-pressed': String(id === 'all') });
    const info = modById[id];
    b.title = id === 'all' ? 'Show every module' : `${id} ${info ? info.name : ''} · ${counts[id] || 0} parts`;
    if (id !== 'all') { b.style.setProperty('--mc', MOD_COLOR[id] || '#55616b'); if (!counts[id]) b.dataset.empty = 'true'; }
    b.addEventListener('click', () => pickModule(id === 'all' ? null : (isoModule === id ? null : id)));
    pills.push(b); modBar.append(b);
  };
  mkPill('all', 'All');
  for (const id of ['M01', 'M02', 'M03', 'M04', 'M05', 'M06', 'M07', 'M08']) mkPill(id, id);
  const exploreBtn = el2('button', 'Explode view', { type: 'button', class: 'cad-btn', 'aria-pressed': 'false' });
  exploreBtn.addEventListener('click', () => {
    const on = explode.value < 50;
    explode.value = on ? 100 : 0; tTarget = on ? 1 : 0; exploreBtn.setAttribute('aria-pressed', String(on)); dirty = true;
  });
  modBar.append(exploreBtn, el2('span', `Grouped by: ${modSource}`, { class: 'cad-modsrc' }));
  bar.after(modBar);

  function pickModule(id) {
    isoModule = id;
    pills.forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.mod === (id || 'all'))));
    visibility();
    if (!id) { select(selected); return; }
    const info = modById[id] || { name: id, kid: '', rungs: [], links: [] };
    const n = counts[id] || 0;
    panel.replaceChildren(el2('span', `${id} · module`, { class: 'eyebrow' }), el2('h3', info.name), el2('p', info.kid));
    if (!n) panel.append(el2('p', 'No part of this module is drawn in the model yet. The bay is being added by the CAD lane (task #132).', { class: 'cad-hint' }));
    else panel.append(el2('p', `${n} parts in the model. Everything else is faded.`, { class: 'cad-meta' }));
    const wrap = el2('div', null, { class: 'cad-rungs' });
    (info.rungs || []).forEach((r, i) => {
      const box = el2('div', null, { class: `mod-rung r${i + 1}` });
      box.append(el2('span', `Rung ${i + 1} · ${r.title}`, { class: 'mod-rn' }));
      for (const k of r.badges) box.append(el2('span', BADGE[k][0], { class: 'bd ' + BADGE[k][1] }));
      box.append(el2('p', r.short || r.text));
      wrap.append(box);
    });
    panel.append(wrap);
    const links = el2('div', null, { class: 'cad-links' });
    links.append(link('upgrades.html#' + id.toLowerCase(), 'Swap card for ' + id));
    for (const [label, href] of info.links || []) links.append(link(href, label));
    panel.append(links);
  }

  explode.addEventListener('input', () => { tTarget = explode.value / 100; dirty = true; });
  cut.addEventListener('input', () => { clip.constant = cut.value >= 100 ? 9999 : (cut.value / 100) * 300 - 150; dirty = true; });
  glassBox.addEventListener('change', visibility);
  el.querySelectorAll('[data-view]').forEach((b) => b.addEventListener('click', () => go(b.dataset.view)));
  el.querySelector('#cad-reset').addEventListener('click', () => {
    explode.value = 0; cut.value = 100; tTarget = 0; clip.constant = 9999; hidden.clear(); isolated = null; isoModule = null;
    pills.forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.mod === 'all'))); exploreBtn.setAttribute('aria-pressed', 'false');
    legend.querySelectorAll('input').forEach((i) => { i.checked = true; });
    legend.querySelectorAll('button[data-asm]').forEach((b) => b.setAttribute('aria-pressed', 'false'));
    select(null); visibility(); go('iso');
  });

  function resize() {
    const w = stage.clientWidth, h = stage.clientHeight;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    dirty = true;
  }
  new ResizeObserver(resize).observe(stage);
  controls.addEventListener('change', () => { dirty = true; });

  function frame() {
    if (Math.abs(tTarget - t) > 0.002) { t += (tTarget - t) * 0.14; layout(); } else if (t !== tTarget) { t = tTarget; layout(); }
    if (controls.update()) dirty = true;
    if (dirty) { renderer.render(scene, camera); dirty = false; }
    requestAnimationFrame(frame);
  }
  el.classList.add('cad-ready');
  resize(); layout(); visibility(); paint(); select(null); go('iso');
  frame();
}

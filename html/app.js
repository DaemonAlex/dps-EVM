/* DPS Fleet panel: a floating search bar with the grouped list under it.
   The client (Lua) owns data, grouping and card text; this file renders and routes keys.
   Two modes share the bar: Browse (the fleet list) and Workshop (option sheets for the
   vehicle you are in or targeting). Workshop sheets are built in Lua and rendered here
   from their descriptors, so a new section needs no change in this file.
   Nothing here polls: every change is a user action or a message from the client. */
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'dps-fleet';
  const $ = (s) => document.querySelector(s);
  const app = $('#app'), bar = $('#bar'), panel = $('#panel'), list = $('#list'), q = $('#q'), hint = $('#hint');
  const ws = $('#ws'), wslist = $('#wslist'), chips = $('#chips');
  const ICON = { automobile: 'fa-car-side', bike: 'fa-motorcycle', heli: 'fa-helicopter', plane: 'fa-plane', boat: 'fa-ship', trailer: 'fa-trailer', train: 'fa-train' };
  const TYPE = { automobile: 'Car / truck', bike: 'Bike', heli: 'Helicopter', plane: 'Plane', boat: 'Boat', trailer: 'Trailer', train: 'Train' };
  const PLACE = { browse: 'Search a vehicle, a department, a kind… (F7 closes)', workshop: 'Filter options… (F7 closes)' };
  const HINT = {
    type: '<kbd>↓</kbd> browse &nbsp;<kbd>Enter</kbd> spawn &nbsp;<kbd>⇧Enter</kbd> beside &nbsp;<kbd>Esc</kbd> close',
    browse: '<kbd>↑↓</kbd> move &nbsp;<kbd>Enter</kbd> spawn &nbsp;<kbd>C</kbd> card &nbsp;<kbd>H</kbd> handling &nbsp;<kbd>F</kbd> fav &nbsp;<kbd>W</kbd> workshop &nbsp;<kbd>X</kbd> remove · type to search',
    ws: '<kbd>↑↓</kbd> move &nbsp;<kbd>Enter</kbd> switch / choose &nbsp;<kbd>←→</kbd> levels &nbsp;<kbd>Esc</kbd> back · type to filter options',
  };
  const S = { byModel: {}, total: 0, recent: [], favs: new Set(), deptNames: {}, deptCodes: {}, catLabels: {}, chip: 'all', rows: [], sel: -1, open: false, pmode: 'browse', want: 'browse', focus: 'type', timer: null, infoTimer: null };
  const W = { sections: [], sec: null, icon: {}, sheet: null, rows: [], sel: -1, openKey: null, ci: -1, vehicle: null, hex: {}, note: '', req: 0 };

  const store = (k, d) => { try { const v = localStorage.getItem(k); return v ? JSON.parse(v) : d; } catch (e) { return d; } };
  const save = (k, v) => { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) {} };
  const esc = (s) => String(s == null ? '' : s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const money = (n) => '$' + (Number(n) || 0).toLocaleString('en-US');
  const fmt = (n, d) => (n == null || isNaN(n)) ? '-' : Number(n).toFixed(d == null ? 2 : d);
  function post(name, body) {
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body || {}) })
      .then((r) => r.json()).catch(() => ({ ok: false }));
  }

  let tt;
  function toast(html, bad) { const t = $('#toast'); t.innerHTML = html; t.classList.toggle('bad', !!bad); t.classList.add('on'); clearTimeout(tt); tt = setTimeout(() => t.classList.remove('on'), 2000); }
  function copy(text) {
    const ta = document.createElement('textarea'); ta.value = text; ta.setAttribute('readonly', ''); ta.style.cssText = 'position:fixed;opacity:0';
    document.body.appendChild(ta); ta.select();
    let ok = false; try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
    document.body.removeChild(ta);
    if (!ok && navigator.clipboard) return navigator.clipboard.writeText(text).then(() => true, () => false);
    return Promise.resolve(ok);
  }

  /* ---------- rendering: browse ---------- */
  const sub = (v) => v.category === 'emergency' ? (v.kind || 'Emergency') : (S.catLabels[v.category] || v.category);
  const photo = (v, big) => v.photo ? `<img src="${esc(v.photo)}" alt=""${big ? '' : ' loading="lazy"'}>` : `<i class="fa-solid ${ICON[v.type] || 'fa-car-side'}"></i>`;
  function rowHtml(v, i) {
    const em = v.category === 'emergency';
    const right = em ? `<span class="badge" title="${esc(S.deptNames[v.dept] || v.dept || '')}">${esc(S.deptCodes[v.dept] || v.dept || '')}</span>`
      : (v.price ? `<span class="price">${money(v.price)}</span>` : '<span class="price dim">not sold</span>');
    return `<div class="row${S.favs.has(v.model) ? ' fav' : ''}" data-i="${i}" role="option"><div class="thumb">${photo(v)}</div><div class="txt"><div class="nm" title="${esc(v.name)}">${esc(v.brand ? v.brand + ' ' : '')}${esc(v.name)}</div><div class="mt"><code>${esc(v.model)}</code> · ${esc(sub(v))}${v.pack && v.pack !== 'vanilla' ? ' · ' + esc(v.pack) : ''}</div></div><div class="rt">${right}<i class="fa-solid fa-star st"></i></div></div>`;
  }
  function detHtml(v, d) {
    const em = v.category === 'emergency', info = (d && d.info) || {}, h = d && d.handling, fav = d && d.favorite;
    const third = em ? `<label>Department</label><span title="${esc(S.deptNames[v.dept] || '')}">${esc(S.deptNames[v.dept] || v.dept || '-')}</span>`
      : `<label>Price</label><span class="mono">${v.price ? money(v.price) : 'Not sold'}</span>`;
    const nums = info.missing ? '<div><label>Model</label><span>not streamed on this client</span></div>' : `
      <div><label>Top speed</label><b>${info.speed != null ? info.speed : '-'}<small>km/h</small></b></div>
      <div><label>Seats</label><b>${info.seats != null ? info.seats : '-'}</b></div>
      <div>${third}</div>
      <div><label>Class</label><span>${esc(TYPE[v.type] || v.type)}${em ? ' · ' + esc(v.kind || '') : ''}${info.cls && info.cls !== '-' ? ' · ' + esc(info.cls) : ''}</span></div>
      <div><label>Pack</label><span class="mono" title="${esc(v.pack)}">${esc(v.pack)}</span></div>
      <div><label>Size</label><span class="mono">${info.dims ? `${fmt(info.dims.l, 1)} × ${fmt(info.dims.w, 1)} × ${fmt(info.dims.h, 1)} m` : '-'}</span></div>
      ${h ? `<div><label>Mass</label><b>${fmt(h.fMass, 0)}<small>kg</small></b></div>
      <div><label>Drive</label><span>${(() => { const b = Number(h.fDriveBiasFront); return isNaN(b) ? '-' : (b >= 0.99 ? 'front' : b <= 0.01 ? 'rear' : 'awd ' + fmt(b)); })()} · ${h.nInitialDriveGears != null ? h.nInitialDriveGears + ' gears' : ''}</span></div>
      <div><label>Drive force</label><span class="mono">${fmt(h.fInitialDriveForce)} · brake ${fmt(h.fBrakeForce)} · grip ${fmt(h.fTractionCurveMax)}</span></div>` : ''}`;
    return `<div class="det"><div class="big">${photo(v, true)}</div><div class="nums">${nums}</div>${h ? '' : '<div class="warn">Handling numbers appear once it exists: spawn it or sit in it.</div>'}<div class="acts">
      <button class="pri" data-a="spawn">Spawn <kbd>Enter</kbd></button>
      <button data-a="beside">Spawn beside <kbd>⇧Enter</kbd></button>
      <button data-a="card">Copy card <kbd>C</kbd></button>
      <button data-a="hand">Copy handling <kbd>H</kbd></button>
      <button data-a="fav">${fav ? 'Unfavorite' : 'Favorite'} <kbd>F</kbd></button>
      <button data-a="shop">Workshop <kbd>W</kbd></button>
      <button class="bad" data-a="del">Remove mine <kbd>X</kbd></button>
    </div></div>`;
  }
  function emptyMsg() {
    if (S.chip === 'recent') return 'Nothing spawned yet. Press <kbd>Enter</kbd> on any row.';
    if (S.chip === 'fav') return 'No favorites yet. Press <kbd>F</kbd> on a row.';
    return q.value ? `No match for “${esc(q.value)}”.` : 'Nothing to show.';
  }
  const rowEl = (i) => list.querySelector(`.row[data-i="${i}"]`);

  function render(sections) {
    S.rows = []; S.sel = -1;
    let h = '';
    for (const s of sections) {
      h += `<section class="sec"><h3><span><b>${esc(s.a)}</b>${s.b ? ' <i>—</i> ' + esc(s.b) : ''}</span><em>${s.count}</em></h3>`;
      for (const m of s.models) { const v = S.byModel[m]; if (v) h += rowHtml(v, S.rows.push(v) - 1); }
      h += '</section>';
    }
    list.innerHTML = h || `<div class="empty">${emptyMsg()}</div>`;
    $('#cnt').textContent = `${S.rows.length} / ${S.total}`;
  }
  function refresh(keepSel) {
    const prev = keepSel && S.rows[S.sel] ? S.rows[S.sel].model : null, st = list.scrollTop, o = S.open;
    post('sections', { q: q.value, chip: S.chip }).then((r) => {
      render(r.sections || []);
      if (prev) { list.scrollTop = st; const i = S.rows.findIndex((v) => v.model === prev); select(i < 0 ? 0 : i, o); }
      else { list.scrollTop = 0; select(0, false); }
    });
  }
  function debouncedRefresh() { clearTimeout(S.timer); S.timer = setTimeout(() => refresh(false), 70); }

  function select(i, expand) {
    if (!S.rows.length) { S.sel = -1; return; }
    i = Math.max(0, Math.min(S.rows.length - 1, i));
    const old = list.querySelector('.row.sel');
    if (old) { old.classList.remove('sel'); const d = old.querySelector('.det'); if (d) d.remove(); }
    S.sel = i; if (expand !== undefined) S.open = expand;
    const r = rowEl(i); if (!r) return;
    r.classList.add('sel');
    if (S.open) {
      const v = S.rows[i];
      r.insertAdjacentHTML('beforeend', detHtml(v, null));
      // rest before asking the game to stream the model, so arrowing stays cheap
      clearTimeout(S.infoTimer);
      S.infoTimer = setTimeout(() => post('info', { model: v.model }).then((d) => {
        if (!d.ok || S.rows[S.sel] !== v) return;
        const det = r.querySelector('.det'); if (!det) return;
        det.outerHTML = detHtml(v, d).replace(/^<div class="det">/, '<div class="det">');
      }), 200);
    }
    const H = 30, top = r.offsetTop, bot = top + r.offsetHeight;
    if (r.offsetHeight > list.clientHeight - H || top - H < list.scrollTop) list.scrollTop = top - H;
    else if (bot > list.scrollTop + list.clientHeight) list.scrollTop = bot - list.clientHeight;
  }
  function setFocus(m) { S.focus = m; bar.classList.toggle('focus', m === 'type'); hint.innerHTML = S.pmode === 'workshop' ? HINT.ws : HINT[m]; }

  /* ---------- rendering: workshop ---------- */
  // Values can be numbers, strings, booleans or small objects ({ src, index }, [r,g,b]).
  // Lua hands objects over in no fixed key order, so compare on a sorted-key form.
  function canon(v) {
    if (v === null || v === undefined) return 'null';
    if (Array.isArray(v)) return '[' + v.map(canon).join(',') + ']';
    if (typeof v === 'object') return '{' + Object.keys(v).sort().map((k) => JSON.stringify(k) + ':' + canon(v[k])).join(',') + '}';
    return JSON.stringify(v);
  }
  const same = (a, b) => canon(a) === canon(b);
  const clamp = (n, lo, hi) => Math.max(lo, Math.min(hi, n));
  const wsRowEl = (i) => wslist.querySelector(`.row[data-i="${i}"]`);
  function curChoice(o) {
    for (const c of (o.choices || [])) { if (same(c.value, o.value)) return c; }
    return null;
  }
  // The "no colour known" swatch comes from the palette, never from a literal here.
  let swatchNone = null;
  function noSwatch() {
    if (swatchNone === null) swatchNone = (getComputedStyle(document.documentElement).getPropertyValue('--cd-swatch-none') || '').trim() || 'transparent';
    return swatchNone;
  }
  function hexOf(c) {
    if (!c) return noSwatch();
    if (c.hex) return String(c.hex);
    const v = c.value;
    if (typeof v === 'number') return W.hex[v] || W.hex[String(v)] || noSwatch();
    if (Array.isArray(v) && v.length === 3) return `rgb(${Number(v[0]) || 0},${Number(v[1]) || 0},${Number(v[2]) || 0})`;
    return noSwatch();
  }
  function stepText(o) {
    const v = Number(o.value), max = o.max == null ? null : Number(o.max);
    if (isNaN(v)) return '-';
    if (v <= -1) return 'stock';
    return max == null ? String(v + 1) : `${v + 1}/${max + 1}`;
  }
  function valLine(o) {
    if (o.kind === 'toggle') return o.value ? 'On' : 'Off';
    if (o.kind === 'stepper') { const v = Number(o.value); return v <= -1 ? 'Stock' : `Level ${v + 1}${o.max == null ? '' : ' of ' + (Number(o.max) + 1)}`; }
    if (o.kind === 'pick' || o.kind === 'colour') { const c = curChoice(o); return c ? String(c.label) : 'Not set'; }
    if (o.kind === 'action') return o.value === false ? 'Looks unavailable — click to see why' : '';
    return '';
  }
  function controlHtml(o) {
    if (o.kind === 'toggle') return `<button class="sw${o.value ? ' on' : ''}" data-a="toggle" title="Switch" aria-pressed="${o.value ? 'true' : 'false'}"><span></span></button>`;
    if (o.kind === 'stepper') return `<div class="step"><button data-a="dec" title="Lower">‹</button><b>${esc(stepText(o))}</b><button data-a="inc" title="Higher">›</button></div>`;
    if (o.kind === 'pick' || o.kind === 'colour') {
      const c = curChoice(o);
      const sw = o.kind === 'colour' ? `<span class="swatch" style="background:${esc(hexOf(c))}"></span>` : '';
      return `<button class="pk" data-a="choices" title="Choose">${sw}<span class="lb">${esc(c ? c.label : 'Choose…')}</span><i class="fa-solid fa-chevron-${W.openKey === o.key ? 'up' : 'down'}"></i></button>`;
    }
    return `<button class="go" data-a="do" title="Do it">Run</button>`;
  }
  function choicesHtml(o) {
    let h = '<div class="det choices">';
    (o.choices || []).forEach((c, j) => {
      const on = same(c.value, o.value), sw = o.kind === 'colour' ? `<span class="swatch" style="background:${esc(hexOf(c))}"></span>` : '';
      h += `<button class="ch${on ? ' on' : ''}${W.ci === j ? ' cur' : ''}" data-c="${j}">${sw}<span class="lb">${esc(c.label)}</span></button>`;
    });
    return h + '</div>';
  }
  function wsRowHtml(o, i) {
    const icon = W.icon[W.sec] || 'fa-sliders';
    const dim = o.kind === 'action' && o.value === false;
    const line = valLine(o);
    return `<div class="row${dim ? ' off' : ''}" data-i="${i}" role="option"><div class="thumb"><i class="fa-solid ${esc(icon)}"></i></div>`
      + `<div class="txt"><div class="nm">${esc(o.label)}</div>${line ? `<div class="mt">${esc(line)}</div>` : ''}</div>`
      + `<div class="rt">${controlHtml(o)}</div>${W.openKey === o.key ? choicesHtml(o) : ''}</div>`;
  }
  function renderHead() {
    const v = W.vehicle || {};
    $('#wshead').innerHTML = `<b>${esc(v.name || 'This vehicle')}</b><code>${esc(v.model || '')}</code>${v.plate ? `<span class="plate">${esc(v.plate)}</span>` : ''}`;
  }
  function renderNav() {
    $('#wsnav').innerHTML = W.sections.map((s) => `<button class="chip${s.id === W.sec ? ' on' : ''}" data-s="${esc(s.id)}"><i class="fa-solid ${esc(s.icon || 'fa-sliders')}"></i>${esc(s.label)}</button>`).join('');
  }
  function renderSheet(keepKey) {
    const keep = keepKey || (W.rows[W.sel] ? W.rows[W.sel].key : null);
    if (!W.sheet) {
      W.rows = []; W.sel = -1;
      wslist.innerHTML = `<div class="empty">${esc(W.note || 'Nothing to change here.')}</div>`;
      $('#cnt').textContent = '';
      return;
    }
    const f = q.value.trim().toLowerCase(), all = W.sheet.options || [];
    W.rows = f ? all.filter((o) => String(o.label == null ? '' : o.label).toLowerCase().indexOf(f) >= 0) : all.slice();
    if (!W.rows.length) {
      W.sel = -1;
      wslist.innerHTML = `<div class="empty">${f ? `No option matches “${esc(q.value)}”.` : 'This section has nothing for this vehicle.'}</div>`;
    } else {
      wslist.innerHTML = W.rows.map(wsRowHtml).join('');
    }
    $('#cnt').textContent = `${W.rows.length} option${W.rows.length === 1 ? '' : 's'}`;
    let i = keep ? W.rows.findIndex((o) => o.key === keep) : -1;
    if (i < 0) i = W.rows.length ? 0 : -1;
    W.sel = -1; wsSelect(i);
  }
  function wsSelect(i) {
    if (!W.rows.length) { W.sel = -1; return; }
    i = clamp(i, 0, W.rows.length - 1);
    const old = wslist.querySelector('.row.sel'); if (old) old.classList.remove('sel');
    W.sel = i;
    const r = wsRowEl(i); if (!r) return;
    r.classList.add('sel');
    const top = r.offsetTop, bot = top + r.offsetHeight;
    if (r.offsetHeight > wslist.clientHeight || top < wslist.scrollTop) wslist.scrollTop = top;
    else if (bot > wslist.scrollTop + wslist.clientHeight) wslist.scrollTop = bot - wslist.clientHeight;
  }

  /* ---------- workshop traffic ---------- */
  function wsApply(o, value) {
    if (!o) return;
    // Actions carry no value at all: the key is left out so Lua reads a plain nil.
    const sec = W.sec, body = { section: sec, key: o.key };
    if (value !== undefined && value !== null) body.value = value;
    post('ws:apply', body).then((r) => {
      if (r.message) toast(esc(r.message), !r.ok);
      else if (!r.ok) toast(esc(r.reason || 'That did not work.'), true);
      if (r.gone) { if (S.pmode === 'workshop') setPanelMode('browse'); return; }
      if (W.sec !== sec) return;                  // the section moved on while we waited
      W.openKey = null; W.ci = -1;
      if (r.sheet) { W.sheet = r.sheet; renderSheet(o.key); }
    });
  }
  function loadSection(id) {
    W.sec = id; W.openKey = null; W.ci = -1; W.sheet = null; W.note = '';
    renderNav();
    post('ws:sheet', { section: id }).then((r) => {
      if (W.sec !== id) return;
      if (r.ok && r.sheet) { W.sheet = r.sheet; W.note = ''; }
      else { W.sheet = null; W.note = r.reason || 'This section is not wired up yet.'; }
      renderSheet(null);
    });
  }
  function enterWorkshop(model) {
    const token = ++W.req;
    post('ws:open', { model: model || null }).then((r) => {
      // Back in Browse, or a newer open already asked: drop this answer on the floor.
      if (S.want !== 'workshop' || token !== W.req) return;
      if (!r.ok) { toast(esc(r.reason || 'The workshop is not available here.'), true); S.want = S.pmode; markMode(S.pmode); return; }
      S.pmode = 'workshop';
      W.vehicle = r.vehicle || null; W.sections = r.sections || []; W.hex = r.colourHex || {};
      W.icon = {}; W.sections.forEach((s) => { W.icon[s.id] = s.icon || 'fa-sliders'; });
      markMode('workshop');
      chips.hidden = true; list.hidden = true; ws.hidden = false;
      q.placeholder = PLACE.workshop; q.value = ''; $('#clr').hidden = true;
      renderHead(); renderNav();
      if (!W.sections.length) { W.sheet = null; W.note = 'Nothing is switched on in the workshop config.'; renderSheet(null); }
      else loadSection(W.sections[0].id);
      setFocus(S.focus);
      wslist.focus();
    });
  }
  function markMode(m) { document.querySelectorAll('.mode').forEach((b) => b.classList.toggle('on', b.dataset.m === m)); }
  function setPanelMode(m, model) {
    S.want = m === 'workshop' ? 'workshop' : 'browse';
    if (m === 'workshop') { enterWorkshop(model); return; }
    S.pmode = 'browse'; markMode('browse');
    W.sheet = null; W.rows = []; W.sel = -1; W.openKey = null; W.ci = -1;
    ws.hidden = true; chips.hidden = false; list.hidden = false;
    q.placeholder = PLACE.browse; q.value = ''; $('#clr').hidden = true;
    setFocus('type'); refresh(false);
    setTimeout(() => { q.focus(); }, 20);
  }

  /* ---------- actions: browse ---------- */
  function act(a) {
    const v = S.rows[S.sel]; if (!v) return;
    if (a === 'spawn' || a === 'beside') {
      post('spawn', { model: v.model, mode: a === 'beside' ? 'beside' : 'replace' }).then((r) => {
        if (!r.ok) { toast(esc(r.reason || 'Spawn failed'), true); return; }
        if (r.recent) S.recent = r.recent;
        toast(`${a === 'beside' ? 'Spawned beside you' : 'Spawned'}: ${esc(v.name)} <code>${esc(v.model)}</code>${r.plate ? ' · ' + esc(r.plate) : ''}`);
        if (S.chip === 'recent') refresh(true); else setTimeout(() => select(S.sel, S.open), 400);
      });
    } else if (a === 'card') {
      post('card', { model: v.model }).then((r) => { if (!r.ok) { toast(esc(r.reason || 'No card'), true); return; } copy(r.text).then((ok) => toast(ok ? `Card copied for ${esc(v.name)}` : 'Copy failed', !ok)); });
    } else if (a === 'hand') {
      post('handlingText', { model: v.model }).then((r) => { if (!r.ok) { toast(esc(r.reason || 'No handling yet'), true); return; } copy(r.text).then((ok) => toast(ok ? `Handling copied for ${esc(v.name)}` : 'Copy failed', !ok)); });
    } else if (a === 'fav') {
      post('favorite', { model: v.model }).then((r) => {
        if (!r.ok) return;
        S.favs = new Set(r.favorites || []);
        toast(r.on ? `<i class="fa-solid fa-star" style="color:var(--cd-sun)"></i> ${esc(v.name)} added to favorites` : `${esc(v.name)} removed from favorites`);
        if (S.chip === 'fav') refresh(true); else { const el = rowEl(S.sel); if (el) { el.classList.toggle('fav', r.on); const b = el.querySelector('[data-a=fav]'); if (b) b.innerHTML = (r.on ? 'Unfavorite' : 'Favorite') + ' <kbd>F</kbd>'; } }
      });
    } else if (a === 'shop') {
      setPanelMode('workshop', v.model);
    } else if (a === 'del') {
      post('delete', {}).then((r) => toast(r.ok ? 'Removed' : esc(r.reason || 'Nothing to remove'), !r.ok));
    }
  }
  function close() { post('close', {}); }

  /* ---------- actions: workshop ---------- */
  function wsAct(a, i) {
    const o = W.rows[i]; if (!o) return;
    if (a === 'toggle') { wsApply(o, !o.value); return; }
    if (a === 'inc' || a === 'dec') { wsStepOpt(o, a === 'inc' ? 1 : -1); return; }
    if (a === 'do') { wsApply(o, null); return; }
    if (a === 'choices') { openChoices(o); return; }
  }
  function wsStepOpt(o, d) {
    if (o.kind !== 'stepper') return;
    const lo = o.min == null ? -1 : Number(o.min), hi = o.max == null ? 0 : Number(o.max);
    const v = clamp((Number(o.value) || 0) + d, lo, hi);
    if (v === Number(o.value)) return;
    wsApply(o, v);
  }
  function openChoices(o) {
    if (o.kind !== 'pick' && o.kind !== 'colour') return;
    if (W.openKey === o.key) { W.openKey = null; W.ci = -1; }
    else {
      W.openKey = o.key;
      const cs = o.choices || [];
      W.ci = cs.findIndex((c) => same(c.value, o.value));
      if (W.ci < 0) W.ci = cs.length ? 0 : -1;
    }
    renderSheet(o.key);
    const cur = wslist.querySelector('.ch.cur'); if (cur) cur.scrollIntoView({ block: 'nearest' });
  }
  function moveChoice(d) {
    const o = W.rows.find((x) => x.key === W.openKey); if (!o) return;
    const els = wslist.querySelectorAll('.ch'); if (!els.length) return;
    const next = clamp((W.ci < 0 ? 0 : W.ci) + d, 0, els.length - 1);
    if (els[W.ci]) els[W.ci].classList.remove('cur');
    W.ci = next; els[next].classList.add('cur'); els[next].scrollIntoView({ block: 'nearest' });
  }
  function takeChoice(j) {
    const o = W.rows.find((x) => x.key === W.openKey); if (!o) return;
    const c = (o.choices || [])[j]; if (!c) return;
    wsApply(o, c.value);
  }
  function wsEnter() {
    if (W.openKey != null) { takeChoice(W.ci); return; }
    const o = W.rows[W.sel]; if (!o) return;
    if (o.kind === 'toggle') { wsApply(o, !o.value); return; }
    if (o.kind === 'pick' || o.kind === 'colour') { openChoices(o); return; }
    if (o.kind === 'action') { wsApply(o, null); return; }
    if (o.kind === 'stepper') toast('Use <kbd>←</kbd> <kbd>→</kbd> to change the level');
  }

  /* ---------- events ---------- */
  q.addEventListener('input', () => {
    $('#clr').hidden = !q.value;
    if (S.pmode === 'workshop') { W.openKey = null; W.ci = -1; renderSheet(null); } else debouncedRefresh();
  });
  q.addEventListener('focus', () => setFocus('type'));
  list.addEventListener('focus', () => setFocus('browse'));
  wslist.addEventListener('focus', () => setFocus('browse'));
  $('#clr').addEventListener('click', () => {
    q.value = ''; $('#clr').hidden = true;
    if (S.pmode === 'workshop') renderSheet(null); else refresh(false);
    q.focus();
  });
  $('#close').addEventListener('click', close);
  $('.modes').addEventListener('click', (e) => {
    const b = e.target.closest('.mode'); if (!b) return;
    if (b.dataset.m === S.pmode) return;
    setPanelMode(b.dataset.m, S.pmode === 'browse' && S.rows[S.sel] ? S.rows[S.sel].model : null);
  });
  chips.addEventListener('click', (e) => {
    const c = e.target.closest('.chip'); if (!c) return;
    S.chip = c.dataset.f; chips.querySelectorAll('.chip').forEach((x) => x.classList.toggle('on', x === c));
    refresh(false); q.focus();
  });
  list.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-a]'); if (b) { act(b.dataset.a); list.focus(); return; }
    if (e.target.closest('.det')) return;
    const r = e.target.closest('.row'); if (!r) return;
    const i = +r.dataset.i; (i === S.sel && S.open) ? select(i, false) : select(i, true); list.focus();
  });
  list.addEventListener('error', (e) => { if (e.target.tagName !== 'IMG') return; const r = e.target.closest('.row'); const v = r ? S.rows[+r.dataset.i] : null; e.target.parentNode.innerHTML = `<i class="fa-solid ${ICON[(v || {}).type] || 'fa-car-side'}"></i>`; }, true);
  $('#wsnav').addEventListener('click', (e) => {
    const c = e.target.closest('.chip'); if (!c) return;
    if (c.dataset.s !== W.sec) loadSection(c.dataset.s);
    wslist.focus();
  });
  wslist.addEventListener('click', (e) => {
    const ch = e.target.closest('.ch');
    if (ch) { takeChoice(+ch.dataset.c); wslist.focus(); return; }
    const r = e.target.closest('.row'); if (!r) return;
    const i = +r.dataset.i;
    const b = e.target.closest('button[data-a]');
    if (b) { wsSelect(i); wsAct(b.dataset.a, i); wslist.focus(); return; }
    if (e.target.closest('.det')) return;
    wsSelect(i);
    const o = W.rows[i];
    if (o && (o.kind === 'pick' || o.kind === 'colour')) openChoices(o);
    wslist.focus();
  });
  function move(d) { select(S.sel + d, true); if (S.focus !== 'browse') list.focus(); }

  function wsKey(e, k, inInput) {
    if (k === 'Escape') {
      e.preventDefault();
      if (W.openKey != null) { W.openKey = null; W.ci = -1; renderSheet(null); } else close();
      return;
    }
    if (k === 'ArrowDown' || k === 'ArrowUp') {
      e.preventDefault(); const d = k === 'ArrowDown' ? 1 : -1;
      if (W.openKey != null) moveChoice(d); else { wsSelect(W.sel + d); wslist.focus(); }
      return;
    }
    if (k === 'Enter' || (k === ' ' && !inInput)) { e.preventDefault(); wsEnter(); return; }
    if (k === 'ArrowRight' || k === 'ArrowLeft') { e.preventDefault(); wsStepOpt(W.rows[W.sel], k === 'ArrowRight' ? 1 : -1); return; }
    if (inInput) return;                               // typing filters the options
    if (k === 'Backspace' || k.length === 1) q.focus();
  }

  document.addEventListener('keydown', (e) => {
    if (app.hidden) return;
    const inInput = e.target === q, k = e.key;
    if (k === 'F7') { e.preventDefault(); close(); return; }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (S.pmode === 'workshop') { wsKey(e, k, inInput); return; }
    if (k === 'ArrowDown') { e.preventDefault(); move(1); return; }
    if (k === 'ArrowUp') { e.preventDefault(); move(-1); return; }
    if (k === 'Enter') { e.preventDefault(); act(e.shiftKey ? 'beside' : 'spawn'); return; }
    if (k === 'Escape') { e.preventDefault(); if (q.value) { q.value = ''; $('#clr').hidden = true; refresh(false); q.focus(); } else close(); return; }
    if (inInput) return; // typing mode: letters are search text
    const acts = { c: 'card', f: 'fav', h: 'hand', w: 'shop', x: 'del' }; const a = acts[k.toLowerCase()];
    if (a) { e.preventDefault(); act(a); return; }
    if (k === ' ') { e.preventDefault(); select(S.sel, !S.open); return; }
    if (k === 'Backspace' || k.length === 1) q.focus(); // type-ahead jumps back to the search box
  });

  /* ---------- move and resize, remembered per player ---------- */
  const geo = store('dps-fleet-geo', {});
  function applyGeo() {
    if (geo.w) document.documentElement.style.setProperty('--w', Math.max(480, Math.min(1100, geo.w)) + 'px');
    if (geo.h) document.documentElement.style.setProperty('--h', Math.max(180, Math.min(window.innerHeight * 0.85, geo.h)) + 'px');
    if (geo.x != null && geo.y != null) { app.style.left = geo.x + 'px'; app.style.top = geo.y + 'px'; app.style.transform = 'none'; }
  }
  function drag(handle, onMove, onEnd) {
    let sx = 0, sy = 0, active = false;
    handle.addEventListener('pointerdown', (e) => { sx = e.clientX; sy = e.clientY; active = true; handle.setPointerCapture(e.pointerId); handle.classList.add('on'); e.preventDefault(); onMove.start && onMove.start(); });
    handle.addEventListener('pointermove', (e) => { if (active) onMove(e.clientX - sx, e.clientY - sy); });
    handle.addEventListener('pointerup', () => { active = false; handle.classList.remove('on'); onEnd && onEnd(); save('dps-fleet-geo', geo); });
  }
  let base = {};
  const mover = (dx, dy) => { app.style.left = (base.x + dx) + 'px'; app.style.top = (base.y + dy) + 'px'; app.style.transform = 'none'; geo.x = base.x + dx; geo.y = base.y + dy; };
  mover.start = () => { const r = app.getBoundingClientRect(); base = { x: r.left, y: r.top }; };
  drag($('#grip'), mover);
  const wider = (dx) => { geo.w = Math.max(480, Math.min(1100, base.w + dx)); document.documentElement.style.setProperty('--w', geo.w + 'px'); };
  wider.start = () => { base.w = app.getBoundingClientRect().width; };
  drag($('#wgrip'), wider);
  const taller = (dx, dy) => { geo.h = Math.max(180, Math.min(window.innerHeight * 0.85, base.h + dy)); document.documentElement.style.setProperty('--h', geo.h + 'px'); };
  taller.start = () => { base.h = panel.getBoundingClientRect().height; };
  drag($('#hgrip'), taller);

  /* ---------- messages from the client ---------- */
  window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
      S.byModel = {}; (m.vehicles || []).forEach((v) => { S.byModel[v.model] = v; });
      S.total = m.total || 0; S.recent = m.recent || []; S.favs = new Set(m.favorites || []);
      S.deptNames = m.deptNames || {}; S.deptCodes = m.deptCodes || {}; S.catLabels = m.categoryLabels || {};
      S.chip = 'all'; chips.querySelectorAll('.chip').forEach((x) => x.classList.toggle('on', x.dataset.f === 'all'));
      S.pmode = 'browse'; S.want = 'browse'; markMode('browse');
      W.sheet = null; W.rows = []; W.sel = -1; W.openKey = null; W.ci = -1; W.sec = null; W.req++;
      ws.hidden = true; chips.hidden = false; list.hidden = false;
      q.value = ''; q.placeholder = PLACE.browse; $('#clr').hidden = true;
      applyGeo(); app.hidden = false; setFocus('type'); refresh(false);
      setTimeout(() => { if (S.pmode === 'browse') q.focus(); }, 30);
      if (m.mode === 'workshop') setPanelMode('workshop', null);
    } else if (m.action === 'close') {
      app.hidden = true;
    }
  });
})();

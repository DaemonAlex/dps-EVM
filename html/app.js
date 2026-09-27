/* DPS Fleet panel: a floating search bar with the grouped list under it.
   The client (Lua) owns data, grouping and card text; this file renders and routes keys.
   Nothing here polls: every change is a user action or a message from the client. */
(function () {
  const RES = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'dps-carmenu';
  const $ = (s) => document.querySelector(s);
  const app = $('#app'), bar = $('#bar'), panel = $('#panel'), list = $('#list'), q = $('#q'), hint = $('#hint');
  const ICON = { automobile: 'fa-car-side', bike: 'fa-motorcycle', heli: 'fa-helicopter', plane: 'fa-plane', boat: 'fa-ship', trailer: 'fa-trailer', train: 'fa-train' };
  const TYPE = { automobile: 'Car / truck', bike: 'Bike', heli: 'Helicopter', plane: 'Plane', boat: 'Boat', trailer: 'Trailer', train: 'Train' };
  const HINT = {
    type: '<kbd>↓</kbd> browse &nbsp;<kbd>Enter</kbd> spawn &nbsp;<kbd>⇧Enter</kbd> beside &nbsp;<kbd>Esc</kbd> close',
    browse: '<kbd>↑↓</kbd> move &nbsp;<kbd>Enter</kbd> spawn &nbsp;<kbd>C</kbd> card &nbsp;<kbd>H</kbd> handling &nbsp;<kbd>F</kbd> fav &nbsp;<kbd>W</kbd> workshop &nbsp;<kbd>X</kbd> remove · type to search',
  };
  const S = { byModel: {}, total: 0, recent: [], favs: new Set(), deptNames: {}, deptCodes: {}, catLabels: {}, chip: 'all', rows: [], sel: -1, open: false, mode: 'type', timer: null, infoTimer: null };

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

  /* ---------- rendering ---------- */
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
  function setMode(m) { S.mode = m; hint.innerHTML = HINT[m]; bar.classList.toggle('focus', m === 'type'); }

  /* ---------- actions ---------- */
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
      post('workshop', { model: v.model }).then((r) => { if (!r.ok) toast(esc(r.reason || 'Workshop unavailable'), true); });
    } else if (a === 'del') {
      post('delete', {}).then((r) => toast(r.ok ? 'Removed' : esc(r.reason || 'Nothing to remove'), !r.ok));
    }
  }
  function close() { post('close', {}); }

  /* ---------- events ---------- */
  q.addEventListener('input', () => { $('#clr').hidden = !q.value; debouncedRefresh(); });
  q.addEventListener('focus', () => setMode('type'));
  list.addEventListener('focus', () => setMode('browse'));
  $('#clr').addEventListener('click', () => { q.value = ''; $('#clr').hidden = true; refresh(false); q.focus(); });
  $('#close').addEventListener('click', close);
  $('#chips').addEventListener('click', (e) => {
    const c = e.target.closest('.chip'); if (!c) return;
    S.chip = c.dataset.f; document.querySelectorAll('.chip').forEach((x) => x.classList.toggle('on', x === c));
    refresh(false); q.focus();
  });
  list.addEventListener('click', (e) => {
    const b = e.target.closest('button[data-a]'); if (b) { act(b.dataset.a); list.focus(); return; }
    if (e.target.closest('.det')) return;
    const r = e.target.closest('.row'); if (!r) return;
    const i = +r.dataset.i; (i === S.sel && S.open) ? select(i, false) : select(i, true); list.focus();
  });
  list.addEventListener('error', (e) => { if (e.target.tagName !== 'IMG') return; const r = e.target.closest('.row'); const v = r ? S.rows[+r.dataset.i] : null; e.target.parentNode.innerHTML = `<i class="fa-solid ${ICON[(v || {}).type] || 'fa-car-side'}"></i>`; }, true);
  function move(d) { select(S.sel + d, true); if (S.mode !== 'browse') list.focus(); }

  document.addEventListener('keydown', (e) => {
    if (app.hidden) return;
    const inInput = e.target === q, k = e.key;
    if (k === 'ArrowDown') { e.preventDefault(); move(1); return; }
    if (k === 'ArrowUp') { e.preventDefault(); move(-1); return; }
    if (k === 'Enter') { e.preventDefault(); act(e.shiftKey ? 'beside' : 'spawn'); return; }
    if (k === 'Escape') { e.preventDefault(); if (q.value) { q.value = ''; $('#clr').hidden = true; refresh(false); q.focus(); } else close(); return; }
    if (k === 'F7') { e.preventDefault(); close(); return; }
    if (e.ctrlKey || e.metaKey || e.altKey) return;
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
      S.chip = 'all'; document.querySelectorAll('.chip').forEach((x) => x.classList.toggle('on', x.dataset.f === 'all'));
      q.value = ''; $('#clr').hidden = true;
      applyGeo(); app.hidden = false; setMode('type'); refresh(false);
      setTimeout(() => { q.focus(); }, 30);
    } else if (m.action === 'close') {
      app.hidden = true;
    }
  });
})();

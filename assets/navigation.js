// Only observes navigation controls. Never reads forms, storage, cookies or APIs.
// Flutter calls this function on the official main-frame origin only.
(() => {
  if (location.origin !== 'https://leghe.fantacalcio.it') return false;
  if (window.__phNavigation) return true;
  const norm = s => String(s || '').normalize('NFKC').trim()
    .toLocaleLowerCase('it').replace(/\s+/g, ' ');
  const controls = () => Array.from(document.querySelectorAll('a,button,[role="button"]'));
  const label = e => norm(e.getAttribute('aria-label') || e.innerText || e.textContent);
  const isEnabled = e => !e.disabled && e.getAttribute('aria-disabled') !== 'true';
  const matches = (e, names) => names.some(n => label(e) === norm(n));
  // Prefer controls in navigation. Do not use substring matches: "Gestione Rose"
  // must never be mistaken for "Rose", or "Calcolo Giornata" for a calendar.
  const find = names => {
    const all = controls().filter(e => isEnabled(e) && matches(e, names));
    return all.find(e => e.closest('nav,[role="navigation"]')) || all[0];
  };
  let hidden = null;
  let previousDisplay = '';
  const restore = () => {
    if (hidden) hidden.style.display = previousDisplay;
    hidden = null;
  };
  window.__phNavigation = {
    scan(labels, adapt) {
      const available = Object.keys(labels).filter(k => !!find(labels[k]));
      let selected = null;
      for (const key of ['dashboard','rose','calendario','classifica']) {
        const e = find(labels[key]);
        if (e && (e.getAttribute('aria-current') === 'page' ||
            e.getAttribute('aria-selected') === 'true' ||
            e.classList.contains('active') || e.parentElement?.classList.contains('active'))) {
          selected = key;
        }
      }
      // Hide only the small, fixed/sticky five-item bottom navigation. No global
      // CSS, no removal of ads, page menus, consent, league or competition controls.
      if (!adapt) restore();
      if (adapt && !hidden) {
        const anchors = ['dashboard','rose','calendario','classifica','menu']
          .map(k => find(labels[k]));
        if (anchors.every(Boolean)) {
          let candidate = anchors[0].parentElement;
          for (let i=0; candidate && i<4; i++, candidate=candidate.parentElement) {
            const r = candidate.getBoundingClientRect();
            const pos = getComputedStyle(candidate).position;
            if (anchors.every(e => candidate.contains(e)) &&
                r.height > 30 && r.height < 130 &&
                r.top > innerHeight * 0.55 && ['fixed','sticky'].includes(pos)) {
              hidden = candidate; previousDisplay = candidate.style.display;
              candidate.style.display = 'none'; break;
            }
          }
        }
      }
      return {available, selected, adapted: !!hidden};
    },
    click(names) {
      const e = find(names);
      if (!e) return false;
      e.click(); return true;
    },
    restore
  };
  return true;
})();

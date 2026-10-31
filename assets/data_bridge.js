// ph-dom/1. No network interception, fetch, cookies, storage, forms or framework
// internals. Unknown page layouts fail closed. Field selectors are capabilities,
// not claims that the current authenticated website implements them.
(() => {
  if (location.origin !== 'https://leghe.fantacalcio.it') return null;
  const norm = s => String(s || '').normalize('NFKC').replace(/\s+/g,' ').trim();
  const text = e => e ? norm(e.innerText || e.textContent).slice(0,160) : '';
  const key = s => norm(s).toLocaleLowerCase('it').replace(/[.°ªº]/g,'');
  const number = s => /^-?\d+(?:[.,]\d+)?$/.test(norm(s)) ? Number(norm(s).replace(',','.')) : null;
  const image = e => {
    const img = e?.matches('img') ? e : e?.querySelector('img');
    try {
      const u = new URL(img?.getAttribute('src') || '', location.href);
      if (u.protocol !== 'https:' || !img) return null;
      if ([...u.searchParams.keys()].some(k => /token|auth|secret|signature/i.test(k))) return null;
      return u.href;
    } catch (_) { return null; }
  };
  const aliases = {
    rank:['#','pos','posizione'], team:['squadra','team'], owner:['allenatore','fantallenatore','presidente'],
    played:['g','pg','partite'], won:['v','vittorie'], drawn:['n','pareggi'], lost:['p','sconfitte'],
    goalsFor:['gf','g+'], goalsAgainst:['gs','g-'], points:['pt','punti'], total:['pt totali','punti totali'],
    credits:['crediti'], home:['casa','squadra casa'], away:['trasferta','ospiti','squadra ospite'],
    score:['risultato','score'], round:['giornata'], player:['calciatore','giocatore'],
    role:['ruolo'], club:['club','squadra reale'], cost:['costo','prezzo'], value:['quotazione','fvm'],
  };
  const columnKinds = new Set();
  const ranking=[], teams=[], matches=[], players=[];
  for (const table of [...document.querySelectorAll('table')].slice(0,40)) {
    const rows=[...table.querySelectorAll('tr')];
    const headerRow=rows.find(r=>r.querySelector('th'));
    if(!headerRow) continue;
    const heads=[...headerRow.querySelectorAll('th,td')].map(e=>key(text(e)));
    const cols={};
    for(const [kind,names] of Object.entries(aliases)) {
      const i=heads.findIndex(h=>names.includes(h));
      if(i>=0) {cols[kind]=i;columnKinds.add(kind);}
    }
    const roundFromTitle=norm(table.caption?.textContent).match(/(\d+)\s*[ªa°]?\s*giornata/i);
    for(const row of rows.filter(r=>r!==headerRow && r.querySelector('td')).slice(0,1000)) {
      const cells=[...row.querySelectorAll(':scope > td')];
      if(cells.length!==heads.length) continue; // no guessed rowspan/colspan mapping
      const cell=k=>cols[k]===undefined?null:cells[cols[k]];
      const str=k=>text(cell(k)); const num=k=>number(str(k));
      if(cols.team!==undefined && cols.points!==undefined && num('points')!==null) {
        const c=cell('team'); const lines=(c.innerText || c.textContent || '').trim().split(/\n/).map(norm).filter(Boolean);
        const name=text(c.querySelector('[data-team-name],.team-name')) || lines[0];
        if(name && !/[<>]/.test(name)) ranking.push({name,logo:image(c),owner:str('owner') || lines.slice(1).join(' '),rank:num('rank'),points:num('points'),played:num('played'),won:num('won'),drawn:num('drawn'),lost:num('lost'),goalsFor:num('goalsFor'),goalsAgainst:num('goalsAgainst'),total:num('total')});
      } else if(cols.team!==undefined && (cols.owner!==undefined || cols.credits!==undefined)) {
        if(str('team')) teams.push({name:str('team'),owner:str('owner'),credits:num('credits'),logo:image(cell('team'))});
      }
      if(cols.home!==undefined && cols.away!==undefined && str('home') && str('away')) {
        const score=str('score').match(/^(\d+)\s*[-–:]\s*(\d+)$/);
        matches.push({home:str('home'),away:str('away'),homeLogo:image(cell('home')),awayLogo:image(cell('away')),homeScore:score?Number(score[1]):null,awayScore:score?Number(score[2]):null,round:num('round') || (roundFromTitle?Number(roundFromTitle[1]):null)});
      }
      if(cols.player!==undefined && cols.role!==undefined && str('player') && str('role')) {
        players.push({name:str('player'),role:str('role'),club:str('club'),cost:num('cost'),value:num('value'),photo:image(cell('player'))});
      }
    }
  }
  // Explicit semantic annotations: experimental fallback, never fuzzy page text.
  for(const card of [...document.querySelectorAll('[data-home-team][data-away-team]')].slice(0,500)) {
    const home=norm(card.getAttribute('data-home-team')), away=norm(card.getAttribute('data-away-team'));
    if(home && away) matches.push({home,away,homeScore:number(card.getAttribute('data-home-score')),awayScore:number(card.getAttribute('data-away-score')),round:number(card.getAttribute('data-round'))});
  }
  for(const card of [...document.querySelectorAll('[data-team-name][data-team-credits]')].slice(0,500)) {
    teams.push({name:norm(card.getAttribute('data-team-name')),owner:text(card.querySelector('[data-team-owner]')),credits:number(card.getAttribute('data-team-credits')),logo:image(card)});
  }
  const selectedLabels=[...document.querySelectorAll('select')].filter(e=>/lega|competizion/i.test(e.getAttribute('aria-label')||e.name||e.id)).map(e=>text(e.selectedOptions[0])).filter(Boolean);
  const contextLabel=selectedLabels.join(' · ');
  const own=document.querySelector('[data-my-team="true"]');
  const roster=document.querySelector('[data-roster-team]');
  const loginForm=!!document.querySelector('input[autocomplete="current-password"],input[type="password"]');
  const available=[...document.querySelectorAll('a,button,[role="button"]')].map(e=>key(text(e)));
  const leaguePage=['dashboard','classifica','calendario'].every(k=>available.includes(k));
  return JSON.stringify({schema:'ph-dom/1',session:loginForm?'login_form':leaguePage?'league_page':'unknown',contextLabel,
    // Path is never exported or persisted; it isolates in-memory league snapshots.
    scope:contextLabel || location.pathname,
    ownTeam:own?norm(own.getAttribute('data-team-name')):null,
    shirt:own?image(own.querySelector('[data-shirt]')):null,
    rosterTeam:roster?norm(roster.getAttribute('data-roster-team')):null,
    ranking,teams,matches,players,
    capabilities:{tables:document.querySelectorAll('table').length,matchCards:document.querySelectorAll('[data-home-team][data-away-team]').length,teamCards:document.querySelectorAll('[data-team-name][data-team-credits]').length,columnKinds:[...columnKinds]}});
})();

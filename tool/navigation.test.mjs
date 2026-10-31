import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {JSDOM} from 'jsdom';
const source = readFileSync(new URL('../assets/navigation.js', import.meta.url), 'utf8');
const labels = {dashboard:['Dashboard'], rose:['Rose','Squadre'], calendario:['Calendario'],
  classifica:['Classifica'],menu:['Menu','Menù'],gestione_rose:['Gestione Rose']};
function page(html, url='https://leghe.fantacalcio.it/lega') {
  const dom = new JSDOM(html, {url, runScripts:'outside-only'});
  dom.window.eval(source); return dom;
}
test('uses existing controls, never fabricated routes, and preserves form state', () => {
  const dom = page('<input type="password" value="do-not-read"><nav><a id="rose">Rose</a><a>Gestione Rose</a><a aria-current="page">Classifica</a></nav>');
  let clicks = 0; dom.window.document.querySelector('#rose').onclick=()=>clicks++;
  const result = dom.window.__phNavigation.scan(labels, false);
  assert.equal(result.selected,'classifica');
  assert.deepEqual(Array.from(result.available), ['rose','classifica','gestione_rose']);
  assert.equal(dom.window.__phNavigation.click(['Rose']),true);
  assert.equal(clicks,1);
  assert.equal(dom.window.document.querySelector('input').value,'do-not-read');
  assert.equal(dom.window.__phNavigation.click(['Calendario']),false);
});
test('exact matching prevents destructive management command collisions', () => {
  const dom = page('<button>Gestione Rose</button><button disabled>Rose</button>');
  assert.equal(dom.window.__phNavigation.click(['Rose']),false);
  assert.equal(dom.window.__phNavigation.click(['Gestione Rose']),true);
});
test('does not install navigation on other origins', () => {
  const dom = page('<a>Rose</a>', 'https://leghe.fantacalcio.it.evil.test');
  assert.equal(dom.window.__phNavigation,undefined);
});
test('hides only verified fixed five-destination navigation and restores original style', () => {
  const dom = page('<aside id="ad">Pubblicità</aside><nav style="position:fixed;display:flex">'+
    ['Dashboard','Rose','Calendario','Classifica','Menu'].map(x=>`<a>${x}</a>`).join('')+'</nav><main>Content</main>');
  const nav = dom.window.document.querySelector('nav');
  nav.getBoundingClientRect = () => ({height:70, top:700});
  assert.equal(dom.window.__phNavigation.scan(labels,true).adapted,true);
  assert.equal(nav.style.display,'none');
  assert.equal(dom.window.document.querySelector('#ad').style.display,'');
  dom.window.__phNavigation.scan(labels,false);
  assert.equal(nav.style.display,'flex');
});
test('keeps ordinary navigation and all league/competition controls intact', () => {
  const dom = page('<nav>'+['Dashboard','Rose','Calendario','Classifica','Menu'].map(x=>`<a>${x}</a>`).join('')+'</nav><select><option>My league</option></select>');
  assert.equal(dom.window.__phNavigation.scan(labels,true).adapted,false);
  assert.equal(dom.window.document.querySelector('select').value,'My league');
});

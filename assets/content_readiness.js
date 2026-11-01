(() => {
  if (!['interactive', 'complete'].includes(document.readyState)) return false;
  if (!['https:', 'http:'].includes(location.protocol)) return false;
  const body = document.body;
  if (!body) return false;
  const visible = el => {
    if (!el || el.closest('template,script,style,noscript,head,[inert]')) return false;
    for (let p = el; p; p = p.parentElement) {
      const s = getComputedStyle(p);
      if (p.hidden ||
          s.display === 'none' || ['hidden', 'collapse'].includes(s.visibility) ||
          Number(s.opacity || 1) === 0) return false;
    }
    const r = el.getBoundingClientRect();
    return r.width > 0 && r.height > 0 && r.bottom > 0 && r.right > 0 &&
      r.top < innerHeight && r.left < innerWidth;
  };
  if (!visible(body)) return false;
  const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
  let text, checked = 0;
  while ((text = walker.nextNode()) && checked++ < 2500) {
    if (!text.textContent.trim() || !visible(text.parentElement)) continue;
    const range = document.createRange();
    range.selectNodeContents(text);
    const r = range.getBoundingClientRect();
    if (r.width > 0 && r.height > 0 && r.bottom > 0 && r.right > 0 &&
        r.top < innerHeight && r.left < innerWidth) return true;
  }
  for (const el of body.querySelectorAll('input,button,select,textarea,img,video')) {
    if (!visible(el)) continue;
    if (el.matches('input,button,select,textarea') && !el.disabled && el.type !== 'hidden') return true;
    const r = el.getBoundingClientRect();
    if (r.width < 16 || r.height < 16) continue;
    if (el.tagName === 'IMG' && el.complete && el.naturalWidth > 0) return true;
    if (el.tagName === 'VIDEO' && el.readyState >= 2) return true;
  }
  return false;
})()

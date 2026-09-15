document.querySelectorAll('.nav').forEach((nav)=>{
  const toggle=nav.querySelector('.nav-toggle');
  const menu=nav.querySelector('.nav-menu');
  if(!toggle||!menu)return;

  const close=()=>{menu.classList.remove('open');toggle.setAttribute('aria-expanded','false')};
  toggle.addEventListener('click',()=>{
    const open=menu.classList.toggle('open');
    toggle.setAttribute('aria-expanded',String(open));
  });
  menu.querySelectorAll('a').forEach((link)=>link.addEventListener('click',close));
  window.addEventListener('resize',()=>{if(window.innerWidth>800)close()});
});

document.querySelectorAll('a[href="#top"]').forEach((link)=>link.addEventListener('click',(event)=>{
  event.preventDefault();
  history.replaceState(null,'',`${location.pathname}${location.search}#top`);
  window.scrollTo({top:0,left:0,behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth'});
}));

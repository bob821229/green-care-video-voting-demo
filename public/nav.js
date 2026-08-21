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

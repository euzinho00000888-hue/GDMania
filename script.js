(function(){
  const cv=document.getElementById('lanes'), g=cv.getContext('2d');
  const COL=['#c24b99','#00e5ff','#12fa05','#f9393f'], KEYS=['d','f','j','k'];
  const still=matchMedia('(prefers-reduced-motion: reduce)').matches;
  let W,H,dpr,notes=[],fx=[],flash=[0,0,0,0],last=0,spawn=0;

  function size(){
    dpr=window.devicePixelRatio||1;
    const r=cv.getBoundingClientRect();
    W=r.width;H=r.height;cv.width=W*dpr;cv.height=H*dpr;g.setTransform(dpr,0,0,dpr,0,0);
    if(still)draw();
  }
  function arrow(cx,cy,r,l,col){
    const p=[[[-r,0],[.6*r,-r],[.6*r,r]],[[0,r],[-r,-.6*r],[r,-.6*r]],[[0,-r],[-r,.6*r],[r,.6*r]],[[r,0],[-.6*r,-r],[-.6*r,r]]][l];
    g.fillStyle=col;g.beginPath();g.moveTo(cx+p[0][0],cy+p[0][1]);g.lineTo(cx+p[1][0],cy+p[1][1]);g.lineTo(cx+p[2][0],cy+p[2][1]);g.fill();
  }
  function hit(l){flash[l]=1;fx.push({l,t:0});}
  function draw(){
    const lw=W/4,hy=H*.84,nh=Math.min(lw*.42,40),nw=lw*.82;
    g.clearRect(0,0,W,H);
    for(let l=0;l<4;l++){
      g.fillStyle=COL[l]+Math.round((.08+flash[l]*.3)*255).toString(16).padStart(2,'0');
      g.fillRect(l*lw,0,lw,H);
      g.fillStyle='rgba(255,255,255,.08)';g.fillRect(l*lw,0,1,H);
    }
    for(let l=0;l<4;l++){
      const cx=l*lw+lw/2;
      g.strokeStyle=COL[l];g.lineWidth=2;g.strokeRect(cx-nw/2,hy-nh/2,nw,nh);
      arrow(cx,hy,nh*.32,l,'rgba(255,255,255,.5)');
    }
    for(const n of notes){
      const cx=n.l*lw+lw/2;
      g.fillStyle=COL[n.l];g.fillRect(cx-nw/2,n.y-nh/2,nw,nh);
      arrow(cx,n.y,nh*.32,n.l,'#fff');
    }
    for(const e of fx){
      const k=e.t/.35;
      g.strokeStyle=COL[e.l];g.globalAlpha=1-k;g.lineWidth=3;
      g.beginPath();g.arc(e.l*lw+lw/2,hy,nh*(.6+k),0,7);g.stroke();g.globalAlpha=1;
    }
  }
  function tick(t){
    const dt=Math.min((t-last)/1000,.05);last=t;
    const hy=H*.84,spd=H*.6;
    spawn-=dt;
    if(spawn<=0){notes.push({l:Math.floor(Math.random()*4),y:-20});spawn=.3+Math.random()*.25;}
    for(const n of notes)n.y+=spd*dt;
    notes=notes.filter(n=>{if(n.y>=hy){hit(n.l);return false;}return true;});
    for(const e of fx)e.t+=dt;
    fx=fx.filter(e=>e.t<.35);
    for(let l=0;l<4;l++)flash[l]=Math.max(0,flash[l]-dt*4);
    draw();requestAnimationFrame(tick);
  }
  addEventListener('resize',size);
  addEventListener('keydown',e=>{const l=KEYS.indexOf(e.key.toLowerCase());if(l>-1&&!e.repeat){hit(l);if(still)draw();}});
  cv.addEventListener('pointerdown',e=>{const r=cv.getBoundingClientRect();hit(Math.min(3,Math.floor((e.clientX-r.left)/r.width*4)));if(still)draw();});
  size();
  if(still){for(let i=0;i<7;i++)notes.push({l:i%4,y:H*(.1+i*.1)});hit(1);draw();}
  else requestAnimationFrame(tick);
})();

/* ES5: Dream Seeker's embedded browser. All sonar graphics are client-side mock contacts. */
window.initNavigation = function (source, initial) {
  var state = initial, routesKey = '', epoch = Date.now() - (state.sonar_phase || 0) * (state.sonar_period || 2.744) * 1000;
  var sonar = document.getElementById('nav-sonar'), ctx = sonar.getContext('2d');
  var map = document.getElementById('nav-map'), mapCtx = map.getContext('2d');
  var grid = document.createElement('canvas');
  grid.width = grid.height = sonar.width;
  var g = grid.getContext('2d'), size = sonar.width, centre = size / 2, radius = centre - 32;
  var contacts = [[-.12, .13], [.27, -.18], [-.48, -.34], [.61, .25], [-.3, .67], [.2, -.71]];
  function text(id, value) { document.getElementById(id).textContent = value; }
  function metres(value) { return Math.round(value || 0).toLocaleString() + ' м'; }
  function command(action, value) {
    window.location.href = 'byond://?src=' + source + ';action=' + action + ';value=' + encodeURIComponent(value || '');
  }
  function circle(context, x, y, r) { context.beginPath(); context.arc(x, y, r, 0, Math.PI * 2); }
  function drawGrid() {
    g.clearRect(0, 0, size, size);
    g.strokeStyle = '#244f2e'; g.lineWidth = 1;
    var i, a, r;
    for (i = 1; i <= 4; i++) { circle(g, centre, centre, radius * i / 4); g.stroke(); }
    for (i = 0; i < 12; i++) {
      a = i * Math.PI / 6;
      g.beginPath(); g.moveTo(centre, centre); g.lineTo(centre + Math.sin(a) * radius, centre - Math.cos(a) * radius); g.stroke();
    }
    g.strokeStyle = '#7baf65'; g.fillStyle = '#7baf65'; g.font = '11px Consolas, monospace'; g.textAlign = 'center';
    for (i = 0; i < 72; i++) {
      a = i * Math.PI / 36; r = radius + (i % 6 ? 4 : 9);
      g.beginPath(); g.moveTo(centre + Math.sin(a) * radius, centre - Math.cos(a) * radius);
      g.lineTo(centre + Math.sin(a) * r, centre - Math.cos(a) * r); g.stroke();
      if (!(i % 6)) g.fillText(i * 5, centre + Math.sin(a) * (radius + 20), centre - Math.cos(a) * (radius + 20) + 4);
    }
  }
  function drawMap() {
    var w = map.width, h = map.height, routes = state.routes || [], max = Math.max(1, state.position || 0), i;
    var points = [{name: state.origin || 'Нырок', position: state.position || 0, own: true}];
    for (i = 0; i < routes.length; i++) { points.push(routes[i]); max = Math.max(max, routes[i].position || 0); }
    mapCtx.clearRect(0, 0, w, h);
    mapCtx.strokeStyle = '#1b3924'; mapCtx.lineWidth = 1;
    for (i = 20; i < w; i += 30) { mapCtx.beginPath(); mapCtx.moveTo(i, 0); mapCtx.lineTo(i, h); mapCtx.stroke(); }
    for (i = 15; i < h; i += 30) { mapCtx.beginPath(); mapCtx.moveTo(0, i); mapCtx.lineTo(w, i); mapCtx.stroke(); }
    function x(p) { return 24 + (p.position || 0) / max * (w - 48); }
    function y(p) { return p.own ? h * .68 : h * (.22 + ((p.position || 0) % 7) * .045); }
    for (i = 0; i < points.length; i++) {
      var p = points[i], selected = p.name === state.selected;
      if (selected) {
        mapCtx.strokeStyle = '#8fb879'; mapCtx.beginPath(); mapCtx.moveTo(x(points[0]), y(points[0])); mapCtx.lineTo(x(p), y(p)); mapCtx.stroke();
      }
      mapCtx.fillStyle = selected ? '#e6ffc5' : '#7ca66a';
      circle(mapCtx, x(p), y(p), p.own ? 4 : 3); mapCtx.fill();
      if (selected) { circle(mapCtx, x(p), y(p), 9); mapCtx.stroke(); }
      mapCtx.font = '10px Consolas, monospace'; mapCtx.textAlign = x(p) > w / 2 ? 'right' : 'left';
      mapCtx.fillText(p.own ? 'НЫРОК' : String(i).replace(/^/, '0'), x(p) + (x(p) > w / 2 ? -8 : 8), y(p) - 9);
    }
  }
  function render() {
    var progress = Math.floor((state.progress || 0) * 100), selected = null, i;
    text('nav-status', state.status || 'Нет связи');
    text('nav-percent', progress + '%');
    document.getElementById('nav-fill').style.width = progress + '%';
    document.getElementById('nav-track').setAttribute('aria-valuenow', progress);
    text('nav-distance', metres(state.travelled) + ' / ' + metres(state.distance) + ' · остаток ' + metres(Math.max(0, (state.distance || 0) - (state.travelled || 0))));
    text('sonar-mode', state.sonar ? 'АКТИВНЫЙ / КРУГОВОЙ ОБЗОР' : 'ПАССИВНЫЙ / БЛИЖНЯЯ ЗОНА');
    text('sonar-range', state.sonar ? 'ШКАЛА 1000 м' : 'ШКАЛА 250 м');
    text('engine-state', state.engines ? 'РАБОТАЮТ' : 'ОСТАНОВЛЕНЫ');
    var engine = document.getElementById('nav-engine'), mode = document.getElementById('nav-mode');
    engine.className = 'engine-switch' + (state.engines ? ' on' : '');
    engine.setAttribute('aria-pressed', !!state.engines); engine.disabled = !!state.travelling;
    document.getElementById('engine-lamp').className = 'lamp' + (state.engines ? ' on' : '');
    mode.className = 'sonar-switch' + (state.sonar ? ' active' : ''); mode.setAttribute('aria-pressed', !!state.sonar);
    for (i = 0; i < (state.routes || []).length; i++) if (state.routes[i].name === state.selected) selected = state.routes[i];
    document.getElementById('nav-depart').disabled = !state.engines || !selected || !!state.travelling;
    text('nav-selected', selected ? selected.name + ' · ' + metres(selected.distance) : 'ТОЧКА НЕ ВЫБРАНА');
    var key = JSON.stringify(state.routes) + state.selected + state.travelling + state.origin;
    if (key !== routesKey) {
      routesKey = key;
      var container = document.getElementById('nav-routes');
      while (container.firstChild) container.removeChild(container.firstChild);
      (state.routes || []).forEach(function (route, index) {
        var button = document.createElement('button'), distance = document.createElement('span');
        button.type = 'button'; button.className = 'nav-route' + (route.name === state.selected ? ' selected' : '');
        button.disabled = !!state.travelling; button.setAttribute('aria-pressed', route.name === state.selected);
        distance.className = 'distance'; distance.textContent = metres(route.distance);
        button.appendChild(distance); button.appendChild(document.createTextNode('0' + (index + 1) + ' ' + route.name));
        button.onclick = function () { command('select', route.name); }; container.appendChild(button);
      });
      drawMap();
    }
  }
  function drawSonar() {
    var phase = ((Date.now() - epoch) / 1000 / (state.sonar_period || 2.744)) % 1;
    var angle = phase * Math.PI * 2 - Math.PI / 2, range = state.sonar ? radius : radius * .36, i;
    ctx.clearRect(0, 0, size, size);
    if (state.sonar) ctx.drawImage(grid, 0, 0);
    ctx.save(); circle(ctx, centre, centre, range + 1); ctx.clip();
    if (!state.sonar) ctx.drawImage(grid, 0, 0);
    if (state.sonar) {
      for (i = 0; i < 12; i++) {
        ctx.fillStyle = 'rgba(113,228,73,' + (.12 * (1 - i / 12)) + ')';
        ctx.beginPath(); ctx.moveTo(centre, centre); ctx.arc(centre, centre, range, angle - i * .025, angle - (i + 1) * .025, true); ctx.closePath(); ctx.fill();
      }
      ctx.strokeStyle = '#a7ef78'; ctx.beginPath(); ctx.moveTo(centre, centre); ctx.lineTo(centre + Math.cos(angle) * range, centre + Math.sin(angle) * range); ctx.stroke();
      ctx.strokeStyle = 'rgba(145,232,110,' + (.55 * (1 - phase)) + ')'; circle(ctx, centre, centre, range * phase); ctx.stroke();
    }
    for (i = 0; i < contacts.length; i++) {
      var contact = contacts[i], distance = Math.sqrt(contact[0] * contact[0] + contact[1] * contact[1]);
      if (!state.sonar && distance > .36) continue;
      var since = (phase - distance + 1) % 1;
      ctx.fillStyle = 'rgba(179,255,114,' + (state.sonar ? Math.max(.08, 1 - since * 1.5) : .55 + .15 * Math.sin(phase * Math.PI * 2)) + ')';
      circle(ctx, centre + contact[0] * radius, centre + contact[1] * radius, 2.5); ctx.fill();
    }
    ctx.fillStyle = '#b6ec96'; ctx.fillRect(centre - 2, centre - 6, 4, 12);
    ctx.restore(); ctx.strokeStyle = state.sonar ? '#80ae66' : '#416444'; circle(ctx, centre, centre, range); ctx.stroke();
  }
  document.getElementById('nav-engine').onclick = function () { command('engine'); };
  document.getElementById('nav-mode').onclick = function () { command('sonar', state.sonar ? 'passive' : 'active'); };
  document.getElementById('nav-depart').onclick = function () { command('depart'); };
  window.updateVoyage = function (raw) {
    var next = JSON.parse(decodeURIComponent(raw));
    if (!!next.sonar !== !!state.sonar) epoch = Date.now() - (next.sonar_phase || 0) * (next.sonar_period || 2.744) * 1000;
    state = next; render();
  };
  drawGrid(); render(); drawSonar();
  // Throttle canvas to 30 fps; hidden windows do no drawing and no refresh requests.
  var lastFrame = 0;
  function frame(time) {
    if (!document.hidden && time - lastFrame >= 33) { drawSonar(); lastFrame = time; }
    window.requestAnimationFrame(frame);
  }
  window.requestAnimationFrame(frame);
  window.setInterval(function () { if (!document.hidden) window.location.href = 'byond://?src=' + source + ';refresh=1'; }, 500);
};

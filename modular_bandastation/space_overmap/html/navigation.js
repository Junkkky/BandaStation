/* ES5 for Dream Seeker; the server alone advances physics and publishes transitions. */
window.initSpaceNavigation = function (source, initial) {
  var state = initial, canvas = document.getElementById('chart'), ctx = canvas.getContext('2d');
  var routes = document.getElementById('routes'), lastRoutes = '', zoom = 1;
  function el(id) { return document.getElementById(id); }
  function text(id, value) { el(id).textContent = value; }
  function command(action, value) {
    window.location.href = 'byond://?src=' + source + ';action=' + action + ';value=' + encodeURIComponent(value === undefined ? '' : value);
  }
  function rounded(number) { return (number || 0).toFixed(1); }
  function render() {
    text('status', state.status);
    text('mode', state.preparing ? 'CONNECTING' : state.docked ? 'DOCKED' : state.autopilot ? 'AUTOPILOT' : state.helm ? 'MANUAL FLIGHT' : 'STANDBY');
    text('position', Math.round(state.x) + ' / ' + Math.round(state.y));
    text('speed', rounded(state.speed)); text('velocity', rounded(state.vx) + ' / ' + rounded(state.vy));
    text('heading', Math.round(state.course) + '° / ' + Math.round(state.ordered_course) + '°');
    text('distance', state.selected ? Math.round(state.distance) : '—'); text('closing', rounded(state.closing_speed));
    text('engines', state.engines + '%');
    el('dock').textContent = state.landing ? 'ПОСАДКА' : 'СТЫКОВКА'; el('dock').disabled = !state.can_dock;
    el('depart').disabled = state.preparing || state.engines <= 0;
    el('autopilot').disabled = state.preparing || state.planning || !state.selected || state.selected === state.docked || state.engines <= 0 || state.throttle <= 0;
    var key = JSON.stringify([state.routes, state.selected, state.docked, state.preparing]);
    if (key !== lastRoutes) {
      lastRoutes = key;
      while (routes.firstChild) { routes.removeChild(routes.firstChild); }
      (state.routes || []).forEach(function (site) {
        var button = document.createElement('button'), detail = document.createElement('small');
        button.textContent = site.name; button.className = site.id === state.selected ? 'selected' : '';
        button.disabled = state.preparing || site.failed;
        detail.textContent = Math.round(site.distance) + ' м' + (site.id === state.docked ? ' · СТЫКОВКА' : site.visited ? ' · ПОСЕЩЕНО' : '');
        button.appendChild(detail); button.onclick = function () { command('select', site.id); }; routes.appendChild(button);
      });
    }
    draw();
  }
  function draw() {
    var w = canvas.width, h = canvas.height, scale = 0.16 * zoom;
    function point(x, y) { return [w / 2 + (x - state.x) * scale, h / 2 - (y - state.y) * scale]; }
    function line(a, b) { ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); }
    ctx.fillStyle = '#080e0d'; ctx.fillRect(0, 0, w, h); ctx.lineWidth = 1; ctx.strokeStyle = '#22352c';
    var grid = 250, left = state.x - w / 2 / scale, bottom = state.y - h / 2 / scale, x, y, p;
    for (x = Math.floor(left / grid) * grid; x < left + w / scale; x += grid) { p = point(x, state.y); line([p[0], 0], [p[0], h]); }
    for (y = Math.floor(bottom / grid) * grid; y < bottom + h / scale; y += grid) { p = point(state.x, y); line([0, p[1]], [w, p[1]]); }
    ctx.font = '11px Consolas,monospace';
    (state.routes || []).forEach(function (site) {
      p = point(site.x, site.y); ctx.strokeStyle = site.id === state.selected ? '#edc587' : '#5b7c66'; ctx.fillStyle = ctx.strokeStyle;
      ctx.beginPath(); ctx.moveTo(p[0], p[1] - 7); ctx.lineTo(p[0] + 7, p[1]); ctx.lineTo(p[0], p[1] + 7); ctx.lineTo(p[0] - 7, p[1]); ctx.closePath(); ctx.stroke();
      ctx.fillText(site.name, p[0] + 10, p[1] - 9);
    });
    if (state.path && state.path.length) {
      ctx.strokeStyle = '#a48e65'; var prior = point(state.x, state.y);
      state.path.forEach(function (node) { var next = point(node[0], node[1]); line(prior, next); prior = next; });
    }
    ctx.strokeStyle = '#7ba7a3'; line([w / 2, h / 2], point(state.x + state.vx * 5, state.y + state.vy * 5));
    ctx.save(); ctx.translate(w / 2, h / 2); ctx.rotate(state.course * Math.PI / 180); ctx.strokeStyle = '#d6edc0';
    ctx.beginPath(); ctx.moveTo(0, -15); ctx.lineTo(7, 10); ctx.lineTo(-7, 10); ctx.closePath(); ctx.stroke(); ctx.restore();
    ctx.fillStyle = '#718870'; ctx.fillText('N ↑', 12, 18); ctx.fillText(Math.round(100 / scale) + ' m', 12, h - 12);
    ctx.strokeStyle = '#718870'; line([12, h - 30], [112, h - 30]);
  }
  ['depart', 'autopilot', 'dock', 'stop'].forEach(function (id) { el(id).onclick = function () { command(id); }; });
  el('set-course').onclick = function () { command('course', el('course').value); };
  el('set-throttle').onclick = function () { command('throttle', el('throttle').value); };
  el('zoom').onchange = function () { zoom = Number(el('zoom').value); draw(); };
  el('course').value = Math.round(state.ordered_course); el('throttle').value = state.throttle;
  window.updateSpace = function (encoded) { state = JSON.parse(decodeURIComponent(encoded)); render(); };
  render(); window.setInterval(function () { command('refresh'); }, 500);
};

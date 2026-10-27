/* ES5 for Dream Seeker. Only the server moves the vessel or discovers sonar contacts. */
window.initNavigation = function (source, initial) {
  var state = initial, routesKey = '', drivesKey = '', received = Date.now();
  var pose = { x: state.x, y: state.y, course: state.course }, previous = pose;
  var sonar = document.getElementById('nav-sonar'), ctx = sonar.getContext('2d');
  var map = document.getElementById('nav-map'), mapCtx = map.getContext('2d');
  var size = sonar.width, centre = size / 2, radius = centre - 32;
  var grid = document.createElement('canvas'); grid.width = grid.height = size;
  var g = grid.getContext('2d');
  function text(id, value) { document.getElementById(id).textContent = value; }
  function metres(value) { return Math.round(value || 0).toLocaleString() + ' м'; }
  function command(action, value) {
    window.location.href = 'byond://?src=' + source + ';action=' + action + ';value=' + encodeURIComponent(value === undefined ? '' : value);
  }
  var updateHelm = window.bindStationTraumaHelm(document.getElementById('nav-throttle'), document.getElementById('nav-throttle-value'), command);
  function circle(context, x, y, r) { context.beginPath(); context.arc(x, y, r, 0, Math.PI * 2); }
  function ship(context, x, y, heading, length, beam) {
    context.save(); context.translate(x, y); context.rotate(heading * Math.PI / 180);
    context.beginPath(); context.moveTo(0, -length / 2);
    context.lineTo(beam / 2, -length / 3); context.lineTo(beam / 2, length / 2);
    context.lineTo(-beam / 2, length / 2); context.lineTo(-beam / 2, -length / 3);
    context.closePath(); context.stroke(); context.restore();
  }
  function drawGrid() {
    g.strokeStyle = '#244f2e'; g.lineWidth = 1;
    var i, a;
    for (i = 1; i <= 4; i++) { circle(g, centre, centre, radius * i / 4); g.stroke(); }
    for (i = 0; i < 12; i++) {
      a = i * Math.PI / 6; g.beginPath(); g.moveTo(centre, centre);
      g.lineTo(centre + Math.sin(a) * radius, centre - Math.cos(a) * radius); g.stroke();
    }
    g.strokeStyle = '#7baf65'; g.fillStyle = '#7baf65'; g.font = '11px Consolas, monospace'; g.textAlign = 'center';
    for (i = 0; i < 72; i++) {
      a = i * Math.PI / 36;
      g.beginPath(); g.moveTo(centre + Math.sin(a) * radius, centre - Math.cos(a) * radius);
      g.lineTo(centre + Math.sin(a) * (radius + (i % 6 ? 4 : 9)), centre - Math.cos(a) * (radius + (i % 6 ? 4 : 9))); g.stroke();
      if (!(i % 6)) g.fillText(i * 5, centre + Math.sin(a) * (radius + 20), centre - Math.cos(a) * (radius + 20) + 4);
    }
  }
  function drawMap() {
    var w = map.width, h = map.height, routes = state.routes || [], i;
    var minX = Math.min(-300, pose.x - 200), maxX = Math.max(400, pose.x + 200);
    var minY = Math.min(-500, pose.y - 200), maxY = Math.max(700, pose.y + 200);
    for (i = 0; i < routes.length; i++) {
      minX = Math.min(minX, routes[i].x - 200); maxX = Math.max(maxX, routes[i].x + 200);
      minY = Math.min(minY, routes[i].y - 200); maxY = Math.max(maxY, routes[i].y + 200);
    }
    var scale = Math.min((w - 35) / (maxX - minX), (h - 30) / (maxY - minY));
    function x(v) { return w / 2 + (v - (maxX + minX) / 2) * scale; }
    function y(v) { return h / 2 - (v - (maxY + minY) / 2) * scale; }
    mapCtx.clearRect(0, 0, w, h); mapCtx.strokeStyle = '#1b3924';
    for (i = 15; i < w; i += 30) { mapCtx.beginPath(); mapCtx.moveTo(i, 0); mapCtx.lineTo(i, h); mapCtx.stroke(); }
    for (i = 15; i < h; i += 30) { mapCtx.beginPath(); mapCtx.moveTo(0, i); mapCtx.lineTo(w, i); mapCtx.stroke(); }
    mapCtx.strokeStyle = '#467e4d';
    (state.chart || []).forEach(function (line) {
      mapCtx.beginPath(); mapCtx.moveTo(x(line.x), y(line.y)); mapCtx.lineTo(x(line.end_x), y(line.end_y)); mapCtx.stroke();
    });
    if (state.autopilot && state.path) {
      mapCtx.strokeStyle = '#b6e391'; mapCtx.beginPath(); mapCtx.moveTo(x(pose.x), y(pose.y));
      state.path.forEach(function (node) { mapCtx.lineTo(x(node[0]), y(node[1])); }); mapCtx.stroke();
    }
    for (i = 0; i < routes.length; i++) {
      var p = routes[i], selected = p.id === state.selected;
      if (selected && !state.autopilot) {
        mapCtx.strokeStyle = '#568f55'; mapCtx.beginPath(); mapCtx.moveTo(x(pose.x), y(pose.y)); mapCtx.lineTo(x(p.x), y(p.y)); mapCtx.stroke();
      }
      mapCtx.strokeStyle = selected ? '#c8ffc0' : '#7ca66a'; circle(mapCtx, x(p.x), y(p.y), selected ? 5 : 3); mapCtx.stroke();
      mapCtx.fillStyle = '#a1da87'; mapCtx.font = '10px Consolas, monospace'; mapCtx.textAlign = 'center';
      mapCtx.fillText(String(i + 1), x(p.x), y(p.y) - 9);
    }
    mapCtx.strokeStyle = '#d5ffc4'; mapCtx.lineWidth = 1.5;
    ship(mapCtx, x(pose.x), y(pose.y), pose.course, 12, 5);
  }
  function render() {
    updateHelm(state.throttle, false);
    text('nav-stop', state.braking ? 'ТОРМОЖЕНИЕ…' : 'ТОРМОЗИТЬ');
    text('nav-braking-distance', 'До остановки ≲ ' + Math.ceil(state.braking_distance || 0) + ' м');
    var progress = Math.floor((state.progress || 0) * 100), selected = null, i;
    text('nav-status', state.status || 'Нет связи'); text('nav-percent', progress + '%');
    document.getElementById('nav-fill').style.width = progress + '%';
    document.getElementById('nav-track').setAttribute('aria-valuenow', progress);
    text('nav-distance', 'Пройдено ' + metres(state.travelled) + (state.selected ? ' · до точки ' + metres(state.remaining) : ' · свободный ход'));
    text('nav-drive-summary', (state.speed || 0) + ' м/с · ' + (state.power || 0) + ' МВт · шум ' + (state.noise || 0) + '%');
    text('nav-arrival', state.selected && state.travelling ? 'Готовность локации: ' + state.loading + '%' + (state.preparing ? ' · подготовка' : '') : '');
    text('nav-position', 'X ' + metres(state.x) + ' / Y ' + metres(state.y) + ' · КУРС ' + Math.round(state.course) + '° → ' + Math.round(state.ordered_course) + '°');
    if (document.activeElement !== document.getElementById('nav-course')) document.getElementById('nav-course').value = Math.round(state.ordered_course);
    text('sonar-mode', state.sonar ? 'АКТИВНЫЙ / ИМПУЛЬС' : 'ПАССИВНЫЙ / ШУМЫ');
    text('sonar-range', 'ШКАЛА ' + state.sonar_range + ' м');
    text('engine-state', state.engines ? 'РАБОТАЮТ' : 'ОСТАНОВЛЕНЫ');
    var engine = document.getElementById('nav-engine'), mode = document.getElementById('nav-mode');
    engine.className = 'engine-switch' + (state.engines ? ' on' : ''); engine.setAttribute('aria-pressed', !!state.engines);
    document.getElementById('engine-lamp').className = 'lamp' + (state.engines ? ' on' : '');
    mode.className = 'sonar-switch' + (state.sonar ? ' active' : ''); mode.setAttribute('aria-pressed', !!state.sonar);
    document.getElementById('nav-depart').disabled = !state.engines || state.helm || state.arrival_pending || (state.preparing && !state.travelling);
    document.getElementById('nav-auto').disabled = !state.engines || !state.selected || state.planning || state.arrival_pending || state.autopilot || state.throttle <= 0;
    text('nav-auto', state.planning ? 'РАСЧЁТ КУРСА…' : state.autopilot ? 'АВТОПИЛОТ ВКЛ.' : 'АВТОПИЛОТ');
    var panel = document.getElementById('nav-drives-panel');
    panel.hidden = !state.physical_drives; panel.style.display = state.physical_drives ? '' : 'none';
    var driveKey = (state.drives || []).length + ':' + state.drive_mode;
    if (state.physical_drives && driveKey !== drivesKey) {
      drivesKey = driveKey;
      var modes = document.getElementById('nav-drive-modes'), drives = document.getElementById('nav-drives');
      while (modes.firstChild) modes.removeChild(modes.firstChild);
      while (drives.firstChild) drives.removeChild(drives.firstChild);
      ['Тихий · до 15% / 18 МВт', 'Крейсерский · до 50% / 72 МВт', 'Полный · до 100% / 180 МВт', 'Форсаж · до 140% / 360 МВт'].forEach(function (label, index) {
        var button = document.createElement('button'); button.type = 'button'; button.textContent = label;
        button.setAttribute('aria-pressed', state.drive_mode === index + 1); button.className = state.drive_mode === index + 1 ? 'selected' : '';
        button.onclick = function () { command('drive_mode', index + 1); }; modes.appendChild(button);
      });
      (state.drives || []).forEach(function (drive, index) {
        var row = document.createElement('div'), button = document.createElement('button'); row.appendChild(document.createTextNode(' '));
        button.type = 'button'; button.onclick = function () { command('drive', index + 1); }; row.appendChild(button); drives.appendChild(row);
      });
    }
    (state.drives || []).forEach(function (drive, index) {
      var row = document.getElementById('nav-drives').children[index]; if (!row) return;
      row.className = 'nav-drive' + (drive.temperature >= 120 || drive.coils < 75 ? ' warning' : '');
      row.firstChild.nodeValue = 'ПГД-' + (index + 1) + ' · ' + drive.status + ' · ' + drive.temperature + ' °C · катушки ' + drive.coils + '% · ' + drive.power + ' МВт · тяга ' + drive.thrust + '% ';
      var button = row.lastChild; button.textContent = drive.tripped ? 'Сброс защиты' : drive.enabled ? 'Отключить' : 'Включить';
      button.disabled = drive.tripped && drive.temperature > 80; button.setAttribute('aria-label', 'ПГД-' + (index + 1) + ': ' + button.textContent);
    });
    for (i = 0; i < state.routes.length; i++) if (state.routes[i].id === state.selected) selected = state.routes[i];
    text('nav-selected', selected ? selected.name + ' · ' + metres(selected.distance) : 'СВОБОДНЫЙ ХОД / ТОЧКА НЕ ВЫБРАНА');
    var key = JSON.stringify(state.routes) + state.selected + state.preparing + state.arrival_pending + state.travelling;
    if (key !== routesKey) {
      routesKey = key; var container = document.getElementById('nav-routes');
      while (container.firstChild) container.removeChild(container.firstChild);
      state.routes.forEach(function (route, index) {
        var button = document.createElement('button'), distance = document.createElement('span');
        button.type = 'button'; button.className = 'nav-route' + (route.id === state.selected ? ' selected' : '');
        button.disabled = state.preparing || state.arrival_pending || route.failed || (!state.travelling && route.id === state.origin);
        button.setAttribute('aria-pressed', route.id === state.selected); distance.className = 'distance'; distance.textContent = metres(route.distance);
        button.appendChild(distance); button.appendChild(document.createTextNode(String(index + 1) + ' ' + route.name + (route.visited ? ' · посещено' : '')));
        button.onclick = function () { command('select', route.id); }; container.appendChild(button);
      });
    }
  }
  function drawSonar() {
    var age = state.sonar_age < 0 ? -1 : state.sonar_age + (Date.now() - received) / 1000;
    var phase = age < 0 ? 0 : Math.min(1, age / state.sonar_period), scale = radius / state.sonar_range;
    ctx.clearRect(0, 0, size, size); ctx.drawImage(grid, 0, 0);
    ctx.save(); circle(ctx, centre, centre, radius); ctx.clip();
    if (state.sonar && age >= 0) {
      ctx.strokeStyle = 'rgba(145,232,110,' + (.65 * (1 - phase)) + ')'; circle(ctx, centre, centre, radius * phase); ctx.stroke();
    }
    function point(x, y, strength) {
      var dx = x - pose.x, dy = y - pose.y, distance = Math.sqrt(dx * dx + dy * dy);
      if (distance > state.sonar_range || (state.sonar && (age < 0 || distance / state.sonar_range > phase))) return;
      ctx.fillStyle = 'rgba(147,255,112,' + strength + ')'; ctx.shadowColor = '#65ec74'; ctx.shadowBlur = 4;
      ctx.fillRect(centre + dx * scale - 1, centre - dy * scale - 1, 3, 3);
    }
    (state.contacts || []).forEach(function (contact) {
      if (contact.kind === 'terrain') {
        var dx = contact.end_x - contact.x, dy = contact.end_y - contact.y;
        var count = Math.ceil(Math.sqrt(dx * dx + dy * dy) * scale / 4), i;
        for (i = 0; i <= count; i++) point(contact.x + dx * i / Math.max(1, count), contact.y + dy * i / Math.max(1, count), .65 * (1 - phase) + .3);
      } else point(contact.x, contact.y, .9);
    });
    ctx.shadowBlur = 0; ctx.strokeStyle = '#b6ec96'; ctx.lineWidth = 1.5;
    ship(ctx, centre, centre, pose.course, Math.max(14, state.length * scale), Math.max(5, state.beam * scale));
    ctx.strokeStyle = '#486d47'; ctx.lineWidth = 1;
    var angle = state.ordered_course * Math.PI / 180; ctx.beginPath(); ctx.moveTo(centre, centre);
    ctx.lineTo(centre + Math.sin(angle) * 38, centre - Math.cos(angle) * 38); ctx.stroke();
    if (state.speed > .05) {
      angle = state.drift * Math.PI / 180; ctx.strokeStyle = '#d4ba79'; ctx.beginPath(); ctx.moveTo(centre, centre);
      ctx.lineTo(centre + Math.sin(angle) * 48, centre - Math.cos(angle) * 48); ctx.stroke();
    }
    ctx.restore(); ctx.strokeStyle = '#80ae66'; circle(ctx, centre, centre, radius); ctx.stroke();
  }
  document.getElementById('nav-engine').onclick = function () { command('engine'); };
  document.getElementById('nav-mode').onclick = function () { command('sonar', state.sonar ? 'passive' : 'active'); };
  document.getElementById('nav-depart').onclick = function () { command('depart'); };
  document.getElementById('nav-stop').onclick = function () { command('stop'); };
  document.getElementById('nav-auto').onclick = function () { command('autopilot'); };
  document.getElementById('nav-port').onclick = function () { command('turn', -15); };
  document.getElementById('nav-starboard').onclick = function () { command('turn', 15); };
  document.getElementById('nav-set-course').onclick = function () { command('course', document.getElementById('nav-course').value); };
  window.updateVoyage = function (raw) {
    previous = { x: pose.x, y: pose.y, course: pose.course }; state = JSON.parse(decodeURIComponent(raw)); received = Date.now(); render();
    if (!state.helm) { pose = { x: state.x, y: state.y, course: state.course }; previous = pose; }
  };
  drawGrid(); render();
  var lastFrame = 0;
  function frame(time) {
    if (!document.hidden && time - lastFrame >= 33) {
      // Interpolate received positions, never predict arrival beyond the server's loading barrier.
      var fraction = Math.min(1, (Date.now() - received) / 500), turn = ((state.course - previous.course + 540) % 360) - 180;
      pose = { x: previous.x + (state.x - previous.x) * fraction, y: previous.y + (state.y - previous.y) * fraction, course: previous.course + turn * fraction };
      drawSonar(); drawMap(); lastFrame = time;
    }
    window.requestAnimationFrame(frame);
  }
  window.requestAnimationFrame(frame);
  window.setInterval(function () { if (!document.hidden) window.location.href = 'byond://?src=' + source + ';refresh=1'; }, 500);
};

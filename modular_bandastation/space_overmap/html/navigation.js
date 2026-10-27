/* ES5 for Dream Seeker; the server alone advances physics and publishes transitions. */
window.initSpaceNavigation = function (source, initial) {
  var state = initial, canvas = document.getElementById('chart'), ctx = canvas.getContext('2d');
  var zoom = 1, focusedContact = null;
  function el(id) { return document.getElementById(id); }
  function text(id, value) { el(id).textContent = value; }
  function command(action, value) {
    window.location.href = 'byond://?src=' + source + ';action=' + action + ';value=' + encodeURIComponent(value === undefined ? '' : value);
  }
  function rounded(number) { return (number || 0).toFixed(1); }
  var updateHelm = window.bindStationTraumaHelm(el('throttle'), el('throttle-value'), command, {
    left: el('strafe-left'), right: el('strafe-right')
  });
  function render() {
    text('status', state.status);
    el('planet').hidden = !state.planet;
    text('planet', state.planet ? state.planet.biome + ' · ' + state.planet.atmosphere + ' · ' + Math.round(state.planet.temperature - 273.15) + ' °C · Требуется EVA-снаряжение' : '');
    text('mode', state.preparing ? 'ПОДГОТОВКА' : state.docked ? (state.landed ? 'НА ПОВЕРХНОСТИ' : 'НА СТОЯНКЕ') : state.autopilot ? 'АВТОПИЛОТ' : state.helm ? 'ПОЛЁТ' : 'ОЖИДАНИЕ');
    text('position', Math.round(state.x) + ' / ' + Math.round(state.y));
    text('speed', rounded(state.speed)); text('velocity', rounded(state.vx) + ' / ' + rounded(state.vy));
    text('heading', Math.round(state.course) + '° / ' + Math.round(state.ordered_course) + '°');
    var etaSeconds = Math.ceil(state.eta || 0);
    var eta = state.eta == null ? '' : ' · ' + Math.floor(etaSeconds / 60) + ':' + ('0' + etaSeconds % 60).slice(-2);
    text('distance', state.selected ? Math.round(state.distance) + eta : '—'); text('closing', rounded(state.closing_speed));
    el('scan').textContent = state.scan_wait > 0 ? 'ПЕРЕЗАРЯДКА ' + state.scan_wait + ' с' : 'СКАНИРОВАНИЕ';
    el('scan').disabled = state.preparing || state.relocating || state.scan_wait > 0;
    text('engines', state.engines + '%');
    text('encounter', (state.encounter || 'Маршрут свободен') + ' · Сканирование ' + (state.sensor_range || 600) + ' м');
    updateHelm(state.throttle, state.relocating, !state.helm || state.preparing || state.docked || state.autopilot || state.braking);
    ['strafe-left', 'strafe-right'].forEach(function (id) {
      el(id).disabled = !state.helm || state.preparing || state.relocating || state.docked || state.autopilot || state.braking;
    });
    ['turn-left', 'turn-right', 'throttle-less', 'throttle-more'].forEach(function (id) { el(id).disabled = !!state.relocating; });
    text('braking-distance', state.braking_distance == null ? 'Нет тяги для торможения' : 'Тормозной путь ≈ ' + Math.ceil(state.braking_distance) + ' м');
    text('stop', state.braking ? 'ТОРМОЖЕНИЕ…' : 'ТОРМОЖЕНИЕ');
    el('depart').textContent = state.landed ? 'ВЗЛЁТ' : 'ОТХОД';
    el('dock').textContent = state.landing ? 'ПОСАДКА' : 'СТЫКОВКА'; el('dock').disabled = !state.can_dock;
    el('depart').disabled = state.preparing || state.engines <= 0;
    el('autopilot').disabled = state.preparing || state.planning || !state.selected || state.selected === state.docked || state.engines <= 0 || state.throttle <= 0;
    ['stop', 'set-course'].forEach(function (id) { el(id).disabled = !!state.relocating; });
    text('target', 'ЦЕЛЬ НЕ ВЫБРАНА');
    (state.routes || []).forEach(function (site) { if (site.id === state.selected) text('target', site.name); });
    el('contact').hidden = focusedContact === null;
    text('contact', focusedContact === null ? '' : 'Отметка ' + focusedContact + ' устарела');
    (state.ship_contacts || []).forEach(function (contact) {
      if (contact.id !== focusedContact) return;
      var distance = Math.sqrt(Math.pow(contact.x - state.x, 2) + Math.pow(contact.y - state.y, 2));
      var channel = contact.mode === 'passive' ? 'пассивный канал' : 'активный канал';
      var identity = contact.identity ? contact.identity.callsign + ' [' + contact.identity.faction + ']' : 'Неопознанное судно';
      text('contact', 'К' + contact.id + ' · ' + identity + ' · ' + channel + ' · давность ' + Math.floor(contact.age) + ' с · дистанция ≈ ' + Math.round(distance) + ' м');
    });
    draw();
  }
  canvas.onclick = function (event) {
    if (state.preparing || state.relocating) return;
    var bounds = canvas.getBoundingClientRect(), scale = 0.16 * zoom;
    var x = (event.clientX - bounds.left) * canvas.width / bounds.width;
    var y = (event.clientY - bounds.top) * canvas.height / bounds.height;
    var closest = null, distance = 14 * 14;
    function consider(site, ship) {
      if (site.failed) return;
      var dx = canvas.width / 2 + (site.x - state.x) * scale - x;
      var dy = canvas.height / 2 - (site.y - state.y) * scale - y;
      var squared = dx * dx + dy * dy;
      if (squared <= distance) { closest = {record: site, ship: ship}; distance = squared; }
    }
    (state.routes || []).forEach(function (site) { consider(site, false); });
    (state.ship_contacts || []).forEach(function (contact) { consider(contact, true); });
    if (closest) {
      focusedContact = closest.ship ? closest.record.id : null;
      render();
      if (!closest.ship) command('select', closest.record.id);
    }
  };
  function draw() {
    var w = canvas.width, h = canvas.height, scale = 0.16 * zoom;
    function point(x, y) { return [w / 2 + (x - state.x) * scale, h / 2 - (y - state.y) * scale]; }
    function line(a, b) { ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke(); }
    ctx.fillStyle = '#080e0d'; ctx.fillRect(0, 0, w, h); ctx.lineWidth = 1; ctx.strokeStyle = '#22352c';
    var grid = 250, left = state.x - w / 2 / scale, bottom = state.y - h / 2 / scale, x, y, p;
    for (x = Math.floor(left / grid) * grid; x < left + w / scale; x += grid) { p = point(x, state.y); line([p[0], 0], [p[0], h]); }
    for (y = Math.floor(bottom / grid) * grid; y < bottom + h / scale; y += grid) { p = point(state.x, y); line([0, p[1]], [w, p[1]]); }
    ctx.font = '11px Consolas,monospace';
    (state.zones || []).forEach(function (zone) {
      p = point(zone.x, zone.y);
      ctx.strokeStyle = zone.kind === 'nebula' ? '#6a718e' : zone.kind === 'meteors' ? '#b77558' : '#897c51';
      ctx.fillStyle = zone.kind === 'nebula' ? 'rgba(90,85,130,.15)' : 'rgba(130,95,50,.10)';
      ctx.beginPath(); ctx.arc(p[0], p[1], zone.radius * scale, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = ctx.strokeStyle; ctx.fillText(zone.name, p[0] - zone.radius * scale, p[1] - zone.radius * scale - 7);
      if (zone.kind === 'meteors') {
        var angle = zone.direction * Math.PI / 180, ax = Math.sin(angle) * 24, ay = -Math.cos(angle) * 24;
        line([p[0] + ax, p[1] + ay], [p[0] - ax, p[1] - ay]);
        line([p[0] - ax, p[1] - ay], [p[0] - ax / 2 + ay / 3, p[1] - ay / 2 - ax / 3]);
        line([p[0] - ax, p[1] - ay], [p[0] - ax / 2 - ay / 3, p[1] - ay / 2 + ax / 3]);
      }
    });
    ctx.strokeStyle = '#bdad80'; ctx.lineWidth = 3;
    (state.terrain || []).forEach(function (rock) { line(point(rock.x, rock.y), point(rock.end_x, rock.end_y)); });
    ctx.lineWidth = 1;
    (state.routes || []).forEach(function (site) {
      p = point(site.x, site.y); ctx.strokeStyle = site.id === state.selected ? '#edc587' : '#5b7c66'; ctx.fillStyle = ctx.strokeStyle;
      ctx.beginPath(); ctx.moveTo(p[0], p[1] - 7); ctx.lineTo(p[0] + 7, p[1]); ctx.lineTo(p[0], p[1] + 7); ctx.lineTo(p[0] - 7, p[1]); ctx.closePath(); ctx.stroke();
      ctx.fillText(site.name, p[0] + 10, p[1] - 9);
    });
    (state.ship_contacts || []).forEach(function (contact) {
      p = point(contact.x, contact.y);
      ctx.strokeStyle = contact.id === focusedContact ? '#edc587' : contact.age >= 20 ? '#6e7664' : '#d2a46a';
      ctx.beginPath(); ctx.arc(p[0], p[1], 5, 0, Math.PI * 2); ctx.stroke();
      ctx.fillStyle = ctx.strokeStyle;
      var label = 'К' + contact.id + (contact.identity ? ' ' + contact.identity.callsign : '');
      ctx.fillText(label + ' · ' + Math.floor(contact.age) + ' с', p[0] + 9, p[1] + 15);
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
  ['depart', 'autopilot', 'dock', 'stop', 'scan'].forEach(function (id) { el(id).onclick = function () { command(id); }; });
  el('set-course').onclick = function () { command('course', el('course').value); };
  el('turn-left').onclick = function () { command('turn', -15); };
  el('turn-right').onclick = function () { command('turn', 15); };
  ['throttle-less', 'throttle-more'].forEach(function (id) {
    el(id).onclick = function () {
      el('throttle').value = Math.max(0, Math.min(100, Number(el('throttle').value) + (id === 'throttle-more' ? 5 : -5)));
      command('throttle', el('throttle').value);
    };
  });
  el('zoom').onchange = function () { zoom = Number(el('zoom').value); draw(); };
  el('course').value = Math.round(state.ordered_course);
  window.updateSpace = function (encoded) { state = JSON.parse(decodeURIComponent(encoded)); render(); };
  render(); window.setInterval(function () { command('refresh'); }, 500);
};

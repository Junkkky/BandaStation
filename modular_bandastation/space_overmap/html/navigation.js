/* ES5 for Dream Seeker; the server alone advances physics and publishes transitions. */
window.initSpaceNavigation = function (source, initial) {
  var state = initial, canvas = document.getElementById('chart'), ctx = canvas.getContext('2d');
  var zoom = 1, focusedContact = null;
  function el(id) { return document.getElementById(id); }
  function text(id, value) { el(id).textContent = value; }
  function command(action, value) {
    window.location.href = 'byond://?src=' + source + ';action=' + action + ';value=' + encodeURIComponent(value === undefined ? '' : value);
  }
  // Sector coordinates use a fixed display scale; travel time and collision geometry stay unchanged.
  function distanceLabel(value) {
    return value === 0 ? '0 а.е.' : (value * state.au_scale).toFixed(Math.abs(value) >= 10 ? 3 : 5) + ' а.е.';
  }
  function speedLabel(value) {
    var kilometres = Math.abs(value) * state.au_scale * 149597870.7;
    var lightSpeed = kilometres / 299792.458;
    return lightSpeed >= 0.01 ? lightSpeed.toFixed(2) + ' c' : Math.round(kilometres) + ' км/с';
  }
  var updateHelm = window.bindStationTraumaHelm(el('throttle'), el('throttle-value'), command, {
    left: el('strafe-left'), right: el('strafe-right')
  });
  function render() {
    var enginesRunning = !!state.engines_running;
    var moored = !!(state.docked || state.coupled);
    el('engine').className = enginesRunning ? 'engine-switch on' : 'engine-switch';
    el('engine').setAttribute('aria-pressed', enginesRunning);
    el('engine').disabled = !!(state.preparing || state.relocating || (!enginesRunning && state.engines <= 0));
    el('engine-lamp').className = enginesRunning && state.engines > 0 ? 'lamp ready' : 'lamp';
    text('engine-state', enginesRunning ? 'ДВИГАТЕЛИ ВКЛ' : 'ДВИГАТЕЛИ ВЫКЛ');
    text('sector-name', state.sector_name || '');
    text('status', state.status);
    el('planet').hidden = !state.planet;
    text('planet', state.planet ? state.planet.biome + ' · ' + state.planet.atmosphere + ' · ' + Math.round(state.planet.temperature - 273.15) + ' °C · ' + (state.planet.breathable ? 'Пригодна для дыхания' : 'Требуется EVA-снаряжение') : '');
    text('mode', state.preparing ? 'ПОДГОТОВКА' : moored ? (state.landed ? 'НА ПОВЕРХНОСТИ' : 'ПРИСТЫКОВАН') : state.autopilot ? 'АВТОПИЛОТ' : state.speed > 0.05 ? 'ПОЛЁТ' : 'СТОП');
    text('position', distanceLabel(state.x) + ' / ' + distanceLabel(state.y));
    var reverse = state.vx * Math.sin(state.course * Math.PI / 180) + state.vy * Math.cos(state.course * Math.PI / 180) < -0.05;
    text('speed', (reverse ? '−' : '') + speedLabel(state.speed));
    var gauge = Math.min(100, Math.max(0, state.speed / 5 * 100));
    var needleAngle = Math.PI * (1 - gauge / 100);
    el('speed-needle').setAttribute('d', 'M50 50L' + (50 + 36 * Math.cos(needleAngle)) + ' ' + (50 - 36 * Math.sin(needleAngle)));
    el('speedometer').setAttribute('aria-valuenow', gauge);
    el('speedometer').setAttribute('aria-valuetext', el('speed').textContent);
    text('heading', Math.round(state.course) + '° / ' + Math.round(state.ordered_course) + '°');
    var etaSeconds = Math.ceil(state.eta || 0);
    var eta = state.eta == null ? '' : ' · ' + Math.floor(etaSeconds / 60) + ':' + ('0' + etaSeconds % 60).slice(-2);
    text('distance', state.selected ? distanceLabel(state.distance) + eta : '—');
    el('scan').disabled = !state.scan_ready;
    el('scan-lamp').className = state.scan_ready ? 'lamp ready' : 'lamp';
    el('scan-lamp').setAttribute('aria-label', state.scan_ready ? 'Сканирование доступно' : 'Сканирование недоступно');
    updateHelm(state.throttle, !enginesRunning || state.coupled || state.preparing || state.relocating || state.jumping, state.preparing || moored || state.autopilot || state.braking, !state.helm && state.throttle === 0 && state.speed <= 0.05);
    ['strafe-left', 'strafe-right'].forEach(function (id) {
      el(id).disabled = !enginesRunning || state.preparing || state.relocating || moored || state.autopilot || state.braking;
    });
    ['turn-left', 'turn-right', 'throttle-less', 'throttle-more'].forEach(function (id) { el(id).disabled = !!(!enginesRunning || state.coupled || state.preparing || state.relocating || state.jumping); });
    text('braking-distance', state.braking_distance == null ? 'Нет тяги для торможения' : 'Тормозной путь ≈ ' + distanceLabel(state.braking_distance));
    text('stop', state.jumping ? 'ОТМЕНА' : state.braking ? 'ТОРМОЖЕНИЕ…' : 'ТОРМОЖЕНИЕ');
    el('depart').textContent = state.landed ? 'ВЗЛЁТ' : 'ОТСТЫКОВКА';
    el('depart').hidden = !moored;
    var selectedContact = (state.ship_contacts || []).some(function (contact) { return contact.id === focusedContact; });
    el('dock').textContent = focusedContact !== null ? 'ЗАПРОС СТЫКОВКИ' : state.landing ? 'ПОСАДКА' : 'СТЫКОВКА';
    el('dock').disabled = focusedContact !== null ? !selectedContact || !state.can_request_ship_dock : !state.can_dock;
    el('depart').disabled = !enginesRunning || state.preparing || state.relocating || state.engines <= 0;
    el('autopilot').disabled = !enginesRunning || state.coupled || state.preparing || state.planning || !state.selected || state.selected === state.docked || state.engines <= 0 || state.throttle <= 0;
    el('docking-request').hidden = !state.docking_request;
    text('docking-request-label', state.docking_request ? 'К' + state.docking_request.contact + ': запрос на стыковку' : '');
    el('accept-ship-dock').disabled = !state.can_request_ship_dock;
    el('stop').disabled = !!state.relocating;
    var routes = el('routes');
    routes.textContent = '';
    (state.routes || []).forEach(function (site) {
      var row = document.createElement('button'), name = document.createElement('span'), distance = document.createElement('span');
      row.type = 'button'; row.className = site.id === state.selected ? 'selected' : '';
      row.disabled = !!(site.failed || state.preparing || state.relocating);
      name.textContent = site.name; row.title = site.name;
      distance.textContent = distanceLabel(site.distance);
      row.appendChild(name); row.appendChild(distance);
      row.onclick = function () { focusedContact = null; command('select', site.id); };
      routes.appendChild(row);
    });
    el('contact').hidden = focusedContact === null;
    text('contact', focusedContact === null ? '' : 'Отметка ' + focusedContact + ' устарела');
    (state.ship_contacts || []).forEach(function (contact) {
      if (contact.id !== focusedContact) return;
      var distance = Math.sqrt(Math.pow(contact.x - state.x, 2) + Math.pow(contact.y - state.y, 2));
      var channel = contact.mode === 'signal' ? 'канал связи' : contact.mode === 'passive' ? 'пассивный канал' : 'активный канал';
      var identity = contact.identity ? contact.identity.callsign + ' [' + contact.identity.faction + ']' : 'Неопознанное судно';
      var motion = 'Движение не определено';
      if (contact.vx != null && contact.vy != null) {
        var speed = Math.sqrt(contact.vx * contact.vx + contact.vy * contact.vy);
        motion = 'Скорость ≈ ' + speedLabel(speed);
        if (speed > 0.05) motion += ' · Направление движения ' + Math.round((Math.atan2(contact.vx, contact.vy) * 180 / Math.PI + 360) % 360) % 360 + '°';
      }
      text('contact', 'К' + contact.id + ' · ' + identity + ' · ' + channel + ' · давность ' + Math.floor(contact.age) + ' с · дистанция ≈ ' + distanceLabel(distance) + ' · ' + motion);
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
    function vector(origin, vx, vy) {
      var speed = Math.sqrt(vx * vx + vy * vy);
      if (speed < 0.01) return;
      var length = Math.max(36, Math.min(140, speed * scale * 90)), dx = vx / speed, dy = -vy / speed;
      var tip = [origin[0] + dx * length, origin[1] + dy * length];
      ctx.lineWidth = 2;
      line(origin, tip);
      line(tip, [tip[0] - dx * 9 + dy * 5, tip[1] - dy * 9 - dx * 5]);
      line(tip, [tip[0] - dx * 9 - dy * 5, tip[1] - dy * 9 + dx * 5]);
      ctx.lineWidth = 1;
    }
    ctx.fillStyle = '#080e0d'; ctx.fillRect(0, 0, w, h); ctx.lineWidth = 1; ctx.strokeStyle = '#22352c';
    var grid = 250, left = state.x - w / 2 / scale, bottom = state.y - h / 2 / scale, x, y, p;
    for (x = Math.floor(left / grid) * grid; x < left + w / scale; x += grid) { p = point(x, state.y); line([p[0], 0], [p[0], h]); }
    for (y = Math.floor(bottom / grid) * grid; y < bottom + h / scale; y += grid) { p = point(state.x, y); line([0, p[1]], [w, p[1]]); }
    ctx.font = '11px Consolas,monospace';
    if (state.star) {
      var star = point(state.star.x, state.star.y);
      ctx.strokeStyle = '#25382e';
      (state.routes || []).forEach(function (site) {
        if (site.kind !== 'planet') return;
        var radius = Math.sqrt(Math.pow(site.x - state.star.x, 2) + Math.pow(site.y - state.star.y, 2));
        ctx.beginPath(); ctx.arc(star[0], star[1], radius * scale, 0, Math.PI * 2); ctx.stroke();
      });
      ctx.fillStyle = '#e7c47b'; ctx.beginPath(); ctx.arc(star[0], star[1], 9, 0, Math.PI * 2); ctx.fill();
      ctx.fillText(state.star.name, star[0] + 14, star[1] - 12);
    }
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
      ctx.beginPath();
      if (site.kind === 'planet') ctx.arc(p[0], p[1], 6, 0, Math.PI * 2);
      else { ctx.moveTo(p[0], p[1] - 7); ctx.lineTo(p[0] + 7, p[1]); ctx.lineTo(p[0], p[1] + 7); ctx.lineTo(p[0] - 7, p[1]); ctx.closePath(); }
      ctx.stroke();
      ctx.fillText(site.name, p[0] + 10, p[1] - 9);
    });
    (state.ship_contacts || []).forEach(function (contact) {
      p = point(contact.x, contact.y);
      ctx.strokeStyle = contact.id === focusedContact ? '#edc587' : contact.age >= 20 ? '#6e7664' : '#d2a46a';
      ctx.beginPath(); ctx.arc(p[0], p[1], 5, 0, Math.PI * 2); ctx.stroke();
      if (contact.id === focusedContact && contact.vx != null && contact.vy != null) vector(p, contact.vx, contact.vy);
      ctx.fillStyle = ctx.strokeStyle;
      var label = 'К' + contact.id + (contact.identity ? ' ' + contact.identity.callsign : '');
      ctx.fillText(label + ' · ' + Math.floor(contact.age) + ' с', p[0] + 9, p[1] + 15);
    });
    if (state.path && state.path.length) {
      ctx.strokeStyle = '#a48e65'; var prior = point(state.x, state.y);
      state.path.forEach(function (node) { var next = point(node[0], node[1]); line(prior, next); prior = next; });
    }
    ctx.strokeStyle = '#91d7d0'; vector([w / 2, h / 2], state.vx, state.vy);
    ctx.save(); ctx.translate(w / 2, h / 2); ctx.rotate(state.course * Math.PI / 180); ctx.strokeStyle = '#d6edc0';
    ctx.beginPath(); ctx.moveTo(0, -15); ctx.lineTo(7, 10); ctx.lineTo(-7, 10); ctx.closePath(); ctx.stroke(); ctx.restore();
    ctx.fillStyle = '#718870'; ctx.fillText('N ↑', 12, 18); ctx.fillText(distanceLabel(100 / scale), 12, h - 12);
    ctx.strokeStyle = '#718870'; line([12, h - 30], [112, h - 30]);
  }
  ['depart', 'autopilot', 'stop', 'scan'].forEach(function (id) { el(id).onclick = function () { command(id); }; });
  el('dock').onclick = function () { command(focusedContact === null ? 'dock' : 'ship_dock', focusedContact === null ? undefined : focusedContact); };
  ['accept', 'decline'].forEach(function (action) {
    el(action + '-ship-dock').onclick = function () { if (state.docking_request) command(action + '_ship_dock', state.docking_request.token); };
  });
  el('engine').onclick = function () { command('engine', state.engines_running ? '0' : '1'); };
  el('turn-left').onclick = function () { command('turn', -15); };
  el('turn-right').onclick = function () { command('turn', 15); };
  ['throttle-less', 'throttle-more'].forEach(function (id) {
    el(id).onclick = function () {
      el('throttle').value = Math.max(-100, Math.min(100, Number(el('throttle').value) + (id === 'throttle-more' ? 5 : -5)));
      command('throttle', el('throttle').value);
    };
  });
  el('zoom').onchange = function () { zoom = Number(el('zoom').value); draw(); };
  window.updateSpace = function (encoded) {
    var next = JSON.parse(decodeURIComponent(encoded));
    if (next.sector !== state.sector) focusedContact = null;
    state = next; render();
  };
  render(); window.setInterval(function () { command('refresh'); }, 500);
};

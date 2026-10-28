/* Shared helm input; physics and permissions remain on the server. */
window.bindStationTraumaHelm = function (lever, readout, command, maneuvers) {
  var dragging = false, pending = null, timer = null, sent = null, sentAt = 0, keys = {};
  var held = {}, maneuverTimer = null, mouseKey = null, maneuverBlocked = false;
  var minimum = Number(lever.min) || 0;
  function sendManeuver() {
    command('maneuver', held[37] && !held[39] ? 8 : held[39] && !held[37] ? 4 : 0);
  }
  function releaseManeuver() {
    if (maneuverTimer === null) return;
    window.clearInterval(maneuverTimer); maneuverTimer = null; held = {}; mouseKey = null;
    command('maneuver', 0);
  }
  function hold(code) {
    if (lever.disabled || maneuverBlocked || held[code]) return;
    held[code] = true; sendManeuver();
    if (maneuverTimer === null) maneuverTimer = window.setInterval(sendManeuver, 200);
  }
  function release(code) {
    if (!held[code]) return;
    delete held[code];
    if (!held[37] && !held[39]) releaseManeuver();
    else sendManeuver();
  }
  if (maneuvers) {
    [[maneuvers.left, 37], [maneuvers.right, 39]].forEach(function (binding) {
      binding[0].addEventListener('mousedown', function (event) {
        if (event.button !== 0) return;
        event.preventDefault(); mouseKey = binding[1]; hold(mouseKey);
      });
    });
  }
  function flush() {
    if (timer !== null) window.clearTimeout(timer);
    timer = null;
    if (pending === null) return;
    var value = pending; pending = null;
    sent = value; sentAt = Date.now(); command('throttle', value);
  }
  function input() {
    if (lever.disabled) return;
    pending = Math.max(minimum, Math.min(100, Number(lever.value)));
    readout.textContent = pending + '%';
    if (Date.now() - sentAt >= 150) flush();
    else if (timer === null) timer = window.setTimeout(flush, 150 - (Date.now() - sentAt));
  }
  function cancel() {
    releaseManeuver();
    if (timer !== null) window.clearTimeout(timer);
    timer = null; pending = null; dragging = false; sent = null;
  }
  lever.addEventListener('mousedown', function () { dragging = true; });
  lever.addEventListener('input', input);
  lever.addEventListener('change', function () { dragging = false; flush(); });
  document.addEventListener('mouseup', function () { dragging = false; flush(); release(mouseKey); mouseKey = null; });
  document.addEventListener('keydown', function (event) {
    var target = event.target, code = event.keyCode, tag = target.tagName;
    if (lever.disabled || event.defaultPrevented || event.ctrlKey || event.altKey || event.metaKey || target.isContentEditable || /TEXTAREA|SELECT/.test(tag) || (tag === 'INPUT' && target.type !== 'range')) return;
    if (tag === 'INPUT' && code !== 32 && !maneuvers) return;
    if (maneuvers && (code === 37 || code === 39)) {
      event.preventDefault();
      hold(code);
      return;
    }
    if (code !== 32 && (code < 37 || code > 40)) return;
    event.preventDefault();
    if ((code === 32 && event.repeat) || Date.now() - (keys[code] || 0) < 150) return;
    keys[code] = Date.now();
    if (code === 32) { cancel(); command('stop'); }
    else if (code === 37 || code === 39) command('turn', code === 37 ? -15 : 15);
    else { lever.value = Math.max(minimum, Math.min(100, Number(lever.value) + (code === 38 ? 5 : -5))); input(); }
  });
  document.addEventListener('keyup', function (event) {
    release(event.keyCode);
  });
  document.addEventListener('focusin', function (event) {
    if (event.target.isContentEditable || /INPUT|TEXTAREA|SELECT/.test(event.target.tagName)) releaseManeuver();
  });
  window.addEventListener('blur', cancel);
  window.addEventListener('unload', cancel);
  document.addEventListener('visibilitychange', function () { if (document.hidden) cancel(); });
  return function (value, disabled, maneuverDisabled, stopped) {
    maneuverBlocked = !!maneuverDisabled;
    lever.disabled = !!disabled;
    if (disabled) cancel();
    else if (maneuverDisabled) releaseManeuver();
    if (!dragging && (stopped || sent === null || Number(value) === sent || Date.now() - sentAt > 1000)) {
      lever.value = value; readout.textContent = value + '%'; sent = Number(value);
    }
  };
};

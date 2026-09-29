/* GOT9 MVP static mock-up — Vanilla JS, localStorage state, no backend. */
(function () {
  'use strict';

  /* ---------- 1. Accessibility font-size toggle (A- / A / A+) ---------- */
  var FONT_SIZES = [14, 16, 20];
  var FONT_KEY = 'got9_fontIdx';
  function fontIdx() {
    var v = parseInt(localStorage.getItem(FONT_KEY) || '1', 10);
    return isNaN(v) ? 1 : Math.min(2, Math.max(0, v));
  }
  function applyFont() {
    document.documentElement.style.fontSize = FONT_SIZES[fontIdx()] + 'px';
    document.querySelectorAll('.a11y button').forEach(function (b, i) {
      b.classList.toggle('cur', i === fontIdx());
    });
  }
  window.got9Font = function (i) {
    localStorage.setItem(FONT_KEY, String(i));
    applyFont();
  };
  document.addEventListener('DOMContentLoaded', applyFont);

  /* ---------- 2. Auth tabs + LINE mock + progressive profiling ---------- */
  window.got9Tab = function (role) {
    document.querySelectorAll('.tab').forEach(function (t) {
      t.classList.toggle('active', t.dataset.roleTab === role);
    });
    document.querySelectorAll('.tabpane').forEach(function (p) {
      p.classList.toggle('active', p.id === 'pane-' + role);
    });
  };

  function saveSession(role, profile) {
    localStorage.setItem('currentUserRole', role);
    try {
      localStorage.setItem('got9_profile_' + role, JSON.stringify(profile || {}));
    } catch (e) { /* storage full — ignore in demo */ }
    window.location.href = 'dashboard.html';
  }
  // "Login with LINE" mock: auto-authenticates, no SMS cost.
  window.got9LineLogin = function (role) {
    saveSession(role, { via: 'LINE-mock', at: new Date().toISOString() });
  };
  // "Login with Gmail" mock: same zero-cost logic via Google account.
  window.got9GoogleLogin = function (role) {
    saveSession(role, { via: 'Gmail-mock', at: new Date().toISOString() });
  };
  window.got9Submit = function (role, form) {
    var data = { via: 'form', at: new Date().toISOString() };
    Array.prototype.forEach.call(form.querySelectorAll('[name]'), function (el) {
      if (el.type === 'radio') { if (el.checked) data[el.name] = el.value; }
      else data[el.name] = el.value;
    });
    if (role === 'C-ID' && data.taxId && !/^\d{13}$/.test(data.taxId.replace(/\D/g, ''))) {
      alert('เลขประจำตัวผู้เสียภาษีต้องมี 13 หลัก');
      return false;
    }
    saveSession(role, data);
    return false;
  };
  window.got9Logout = function () {
    localStorage.removeItem('currentUserRole');
    window.location.href = 'index.html';
  };

  /* ---------- 3. Dashboard renderer ---------- */
  function profileOf(role) {
    try { return JSON.parse(localStorage.getItem('got9_profile_' + role) || '{}'); }
    catch (e) { return {}; }
  }

  function initDashboard() {
    var root = document.getElementById('dashboard');
    if (!root) return;
    var role = localStorage.getItem('currentUserRole') || 'F-ID';
    var profile = profileOf(role);
    document.querySelectorAll('[data-for]').forEach(function (sec) {
      sec.style.display = sec.dataset.for === role ? '' : 'none';
    });
    var who = document.getElementById('whoami');
    if (who) {
      var name = profile.displayName || profile.farmerName || profile.companyName || role;
      who.textContent = role + ' • ' + name;
    }
    if (role === 'F-ID') { initFarmer(profile); }
    if (role === 'B-ID') { initBuyer(profile); }
    if (role === 'C-ID') { initCorporate(profile); }
  }

  /* ----- F-ID: weather + map + offline form ----- */
  function initFarmer(profile) {
    var prov = profile.province || 'เลย';
    var amp = profile.amphoe || 'ภูเรือ';
    var el = document.getElementById('weatherBox');
    if (el) {
      el.innerHTML = 'กำลังโหลดอากาศ ' + amp + '...';
      // Phu Ruea, Loei ~ 17.4036, 101.3667. Free API, no key.
      fetch('https://api.open-meteo.com/v1/forecast?latitude=17.4036&longitude=101.3667&current=temperature_2m,relative_humidity_2m&timezone=Asia%2FBangkok')
        .then(function (r) { if (!r.ok) throw new Error('HTTP ' + r.status); return r.json(); })
        .then(function (j) {
          var t = j.current.temperature_2m, h = j.current.relative_humidity_2m;
          el.innerHTML = '<b>' + amp + ', ' + prov + '</b> — ' + t + '°C • ความชื้น ' + h +
            '% <span class="badge green">สดจาก Open-Meteo</span>';
        })
        .catch(function () {
          el.innerHTML = '<b>' + amp + '</b> — โหลดอากาศไม่ได้ (ออฟไลน์?) ลองใหม่ภายหลัง';
        });
    }
    initMap();
    initActivities();
  }

  var PHU_RUEA = [17.4036, 101.3667];
  // Static mock GeoJSON: 3-ngan plot (~30x40m) + red outer buffer ring (~2m).
  var PLOT_GEOJSON = {
    type: 'FeatureCollection',
    features: [
      { type: 'Feature', properties: { kind: 'buffer' }, geometry: { type: 'Polygon', coordinates: [[
        [101.36648, 17.40344], [101.36690, 17.40344], [101.36690, 17.40376], [101.36648, 17.40376], [101.36648, 17.40344]
      ]] } },
      { type: 'Feature', properties: { kind: 'plot' }, geometry: { type: 'Polygon', coordinates: [[
        [101.36650, 17.40346], [101.36688, 17.40346], [101.36688, 17.40374], [101.36650, 17.40374], [101.36650, 17.40346]
      ]] } }
    ]
  };

  function initMap() {
    var div = document.getElementById('map');
    if (!div || typeof L === 'undefined') return;
    if (div.dataset.done) return;
    div.dataset.done = '1';
    var map = L.map('map').setView(PHU_RUEA, 17);
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19, attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);
    L.geoJSON(PLOT_GEOJSON, {
      style: function (f) {
        return f.properties.kind === 'buffer'
          ? { color: '#C62828', weight: 1, fillColor: '#C62828', fillOpacity: 0.30 }
          : { color: '#1B5E20', weight: 2, fillColor: '#1B5E20', fillOpacity: 0.45 };
      }
    }).addTo(map).bindPopup('แปลงสาธิต 3 งาน (อินทรีย์)');
  }

  /* ----- Offline-first: activities straight to localStorage ----- */
  var ACT_KEY = 'got9_activities';
  function readActs() {
    try { return JSON.parse(localStorage.getItem(ACT_KEY) || '[]'); }
    catch (e) { return []; }
  }
  function renderActs() {
    var ul = document.getElementById('actList');
    if (!ul) return;
    var acts = readActs();
    ul.innerHTML = acts.length ? '' : '<li>ยังไม่มีบันทึก — กรอกด้านบนแล้วกดบันทึก (อยู่ได้แม้ออฟไลน์)</li>';
    acts.slice().reverse().forEach(function (a) {
      var li = document.createElement('li');
      li.innerHTML = '<b></b> <small></small>';
      li.querySelector('b').textContent = a.text;
      li.querySelector('small').textContent = ' • ' + a.at;
      ul.appendChild(li);
    });
    var c = document.getElementById('actCount');
    if (c) c.textContent = acts.length + ' รายการในเครื่อง (localStorage)';
  }
  window.got9AddActivity = function (form) {
    var input = form.querySelector('[name=activity]');
    var text = (input.value || '').trim();
    if (!text) return false;
    var acts = readActs();
    acts.push({ text: text, at: new Date().toLocaleString('th-TH') });
    localStorage.setItem(ACT_KEY, JSON.stringify(acts));
    input.value = '';
    renderActs();
    return false;
  };

  /* ----- B-ID: element banner. C-ID: company card ----- */
  function initBuyer(profile) {
    var b = document.getElementById('elementBanner');
    if (b) {
      var name = profile.displayName || 'สมาชิก';
      b.innerHTML = 'สวัสดี <b>' + escapeHtml(name) + '</b> — ธาตุเจ้าเรือนของคุณคือ <b>ธาตุดิน</b> ' +
        'แนะนำสมุนไพรปรับสมดุล: <b>ตรีผลา</b> <span class="badge brown">วิเคราะห์จากวันเกิด (จำลอง)</span>';
    }
  }
  function initCorporate(profile) {
    var c = document.getElementById('corpCard');
    if (c && profile.companyName) {
      c.innerHTML = '<b>' + escapeHtml(profile.companyName) + '</b> • ภพ.20: ' +
        escapeHtml(profile.taxId || '-') + ' • ติดต่อ ' + escapeHtml(profile.contactPerson || '-') +
        ' ' + escapeHtml(profile.tel || '');
    }
  }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (m) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[m];
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    initDashboard();
    renderActs();
  });
})();

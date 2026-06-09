// Classic worker — no static imports, so this line runs before anything else
self.postMessage({ type: 'log', text: '[worker] script start' });

let instance = null;

async function getInstance() {
  if (instance) return instance;

  self.postMessage({ type: 'log', text: '[worker] dynamic import of openscad-wasm…' });
  let factory;
  try {
    const mod = await import('https://cdn.jsdelivr.net/npm/openscad-wasm@0.0.4/openscad.js');
    self.postMessage({ type: 'log', text: '[worker] mod keys: ' + JSON.stringify(Object.keys(mod)) });
    self.postMessage({ type: 'log', text: '[worker] typeof mod.default=' + typeof mod.default });
    self.postMessage({ type: 'log', text: '[worker] typeof self.OpenSCAD=' + typeof self.OpenSCAD });
    self.postMessage({ type: 'log', text: '[worker] typeof self.Module=' + typeof self.Module });
    factory = mod.createOpenSCAD;
    self.postMessage({ type: 'log', text: '[worker] factory resolved, typeof=' + typeof factory });
  } catch (e) {
    const msg = 'CDN import failed: ' + (e.message || e);
    self.postMessage({ type: 'error', message: msg });
    throw new Error(msg);
  }

  self.postMessage({ type: 'log', text: '[worker] creating WASM instance…' });
  try {
    instance = await factory({
      noInitialRun: true,
      print:    (t) => { console.log('[openscad]', t);  self.postMessage({ type: 'log', text: t }); },
      printErr: (t) => { console.warn('[openscad]', t); self.postMessage({ type: 'log', text: t }); },
    });
    self.postMessage({ type: 'log', text: '[worker] WASM instance ready' });
  } catch (e) {
    const msg = 'WASM init failed: ' + (e.message || e);
    self.postMessage({ type: 'error', message: msg });
    throw new Error(msg);
  }

  return instance;
}

function buildScad(p, mode = 'half') {
  const groove = p.groove_w > 0
    ? `difference() {
                stadium(pad_major + 0.01, pad_minor + 0.01, groove_w);
                stadium(pad_major - 2 * groove_d, pad_minor - 2 * groove_d, groove_w + 0.01);
            }`
    : '';

  const body = `mount_major   = ${p.mount_major};
mount_minor   = ${p.mount_minor};
pad_major     = ${p.pad_major};
pad_minor     = ${p.pad_minor};
fit_clearance = ${p.fit_clearance};
adapter_h     = ${p.adapter_h};
groove_w      = ${p.groove_w};
groove_d      = ${p.groove_d};
ridge_w       = ${p.ridge_w};
ridge_d       = ${p.ridge_d};
peg_r         = 1.0;
peg_len       = 4;
peg_clearance = 0.25;
bore_major    = mount_major + fit_clearance;
bore_minor    = mount_minor + fit_clearance;
peg_y         = (bore_minor + pad_minor) / 4;
$fn = 48;

module stadium(major, minor, h) {
    straight = major - minor;
    hull() {
        translate([ straight / 2, 0, 0]) cylinder(d = minor, h = h, center = true);
        translate([-straight / 2, 0, 0]) cylinder(d = minor, h = h, center = true);
    }
}

module adapter_full() {
    union() {
        difference() {
            stadium(pad_major, pad_minor, adapter_h);
            stadium(bore_major, bore_minor, adapter_h + 1);
            ${groove}
        }
        difference() {
            translate([0, 0, -(adapter_h - ridge_w) / 2])
                stadium(bore_major + 0.02, bore_minor + 0.02, ridge_w);
            translate([0, 0, -(adapter_h - ridge_w) / 2])
                stadium(bore_major - 2 * ridge_d, bore_minor - 2 * ridge_d, ridge_w + 0.1);
        }
    }
}

module adapter_half() {
    difference() {
        union() {
            intersection() {
                adapter_full();
                translate([(pad_major + 1) / 2, 0, 0])
                    cube([pad_major + 1, (pad_minor + 2) * 2, adapter_h + 2], center = true);
            }
            translate([-(peg_len / 2), peg_y, 0])
                rotate([0, 90, 0]) cylinder(r = peg_r, h = peg_len, center = true);
        }
        translate([(peg_len / 2), -peg_y, 0])
            rotate([0, 90, 0]) cylinder(r = peg_r + peg_clearance, h = peg_len + 0.1, center = true);
    }
}

`;

  const footer = mode === 'half'
    ? 'adapter_half();'
    : 'adapter_half();\nrotate([0, 0, 180]) adapter_half();';

  return body + footer;
}

self.onmessage = async ({ data }) => {
  if (data.type !== 'render') return;

  const timeout = setTimeout(() => {
    self.postMessage({ type: 'error', message: 'Render timed out after 60 s' });
  }, 60_000);

  try {
    const inst = await getInstance();
    self.postMessage({ type: 'log', text: '[worker] calling renderToStl…' });
    const result = await inst.renderToStl(buildScad(data.params, data.mode || 'half'));
    instance = null; // renderToStl is one-shot per instance; force fresh next time
    const stl = new TextEncoder().encode(result);
    clearTimeout(timeout);
    self.postMessage({ type: 'result', stl }, [stl.buffer]);
  } catch (err) {
    clearTimeout(timeout);
    instance = null;
    self.postMessage({ type: 'error', message: String(err?.message ?? err ?? 'unknown render error') });
  }
};

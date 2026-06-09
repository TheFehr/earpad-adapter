// ═══════════════════════════════════════════════════════════════════════════════
// Steelseries Arctis Pro → replacement earpad adapter  (two-part, rigid print)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Print TWO copies of this half. Assembly:
//   1. Bring one half in from each side of the Arctis Pro mount.
//   2. Align the inner ridge with the mount's retention groove.
//   3. Press the mating faces together — the pegs lock the halves flush.
//   4. Stretch the replacement earpad over the outer groove; its rubber
//      tension clamps the whole assembly to the mount.
//
// The inner ridge sits in the Arctis Pro's 2 mm × 7 mm retention groove and
// prevents the adapter from shifting axially on the mount.
//
// The Arctis mount is a STADIUM shape: two semicircular ends (Ø 82 mm)
// connected by 15 mm straight sides (97 − 82 = 15 mm).
//
// Print flat face down — no supports needed.
// Recommended: 0.2 mm layers, ≥ 3 perimeters (minimum wall ≈ 1.3 mm).
//
// Tuning:
//   inner fit loose   → decrease fit_clearance (try 0.2)
//   inner fit tight   → increase fit_clearance (try 0.6)
//   ridge won't seat  → decrease ridge_d by 0.5 mm and reprint
//   grommet slips out → increase groove_d (keep min wall ≥ 1 mm)

// ── Arctis Pro mount (measured) ───────────────────────────────────────────────
mount_major  = 97;       // outer, top-bottom total  [mm]
mount_minor  = 82;       // outer, left-right  total [mm]  (= diameter of end circles)
// straight section = mount_major - mount_minor = 15 mm

// ── Replacement earpad inner opening (measured) ───────────────────────────────
pad_major = 106;         // top-bottom  [mm]
pad_minor = 95;          // left-right   [mm]
// assumes same stadium style; straight section = 106 − 95 = 11 mm

// ── Adapter settings ──────────────────────────────────────────────────────────
fit_clearance = 0.4;     // total diametric clearance on inner bore
adapter_h     = 3;       // adapter height [mm]

groove_w = 0;            // outer grommet groove width [mm]  (0 = disabled)
groove_d = 3;            // outer grommet groove depth [mm]

ridge_w  = 1.5;          // inner ridge axial width  [mm]  — Arctis groove: 2 mm high
ridge_d  = 5.0;          // inner ridge radial depth [mm]  — Arctis groove: ~7 mm deep

peg_r         = 1.0;     // alignment peg radius [mm]
peg_len       = 4;       // alignment peg length [mm]
peg_clearance = 0.25;    // peg-to-hole radial clearance [mm]

// ── Derived ───────────────────────────────────────────────────────────────────
bore_major = mount_major + fit_clearance;
bore_minor = mount_minor + fit_clearance;
// Peg Y sits at the centre of the wall on the mating face (X = 0)
peg_y = (bore_minor + pad_minor) / 4;

$fn = 128;

// Stadium: two circles of diameter `minor` whose centres are separated by
// (major − minor) along X, connected by straight sides via hull().
module stadium(major, minor, h) {
    straight = major - minor;
    hull() {
        translate([ straight / 2, 0, 0]) cylinder(d = minor, h = h, center = true);
        translate([-straight / 2, 0, 0]) cylinder(d = minor, h = h, center = true);
    }
}

// Full ring (both halves combined — not printed directly)
module adapter_full() {
    union() {
        // Outer shell with inner bore
        difference() {
            stadium(pad_major, pad_minor, adapter_h);
            stadium(bore_major, bore_minor, adapter_h + 1);
            // Outer grommet groove (disabled; uncomment and set groove_w > 0 to restore)
            //difference() {
            //    stadium(pad_major + 0.01, pad_minor + 0.01, groove_w);
            //    stadium(pad_major - 2*groove_d, pad_minor - 2*groove_d, groove_w + 0.01);
            //}
        }
        // Inner ridge — protrudes into bore, seats in Arctis 2 mm × 7 mm groove
        // Ridge sits flush at the bottom face (headset side)
        difference() {
            translate([0, 0, -(adapter_h - ridge_w) / 2])
                stadium(bore_major + 0.02, bore_minor + 0.02, ridge_w);
            translate([0, 0, -(adapter_h - ridge_w) / 2])
                stadium(bore_major - 2 * ridge_d, bore_minor - 2 * ridge_d, ridge_w + 0.1);
        }
    }
}

// One half (print two copies; second copy rotates 180° around Z on the build plate)
// Mating face is the flat cut at X = 0.
// Peg at +Y protrudes in −X; hole at −Y recesses in +X.
// After 180° Z rotation the second half's hole aligns with the first's peg and vice versa.
module adapter_half() {
    difference() {
        union() {
            // Positive-X half of the ring
            intersection() {
                adapter_full();
                translate([(pad_major + 1) / 2, 0, 0])
                    cube([pad_major + 1, (pad_minor + 2) * 2, adapter_h + 2], center = true);
            }
            // Alignment peg at +Y: protrudes in −X direction from mating face
            translate([-(peg_len / 2), peg_y, 0])
                rotate([0, 90, 0]) cylinder(r = peg_r, h = peg_len, center = true);
        }
        // Alignment hole at −Y: recessed in +X direction into body
        translate([(peg_len / 2), -peg_y, 0])
            rotate([0, 90, 0]) cylinder(r = peg_r + peg_clearance, h = peg_len + 0.1, center = true);
    }
}

adapter_half();

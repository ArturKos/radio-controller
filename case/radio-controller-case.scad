// =============================================================================
// Radio Controller Case — NodeMCU v2 + CC1101 (SMA antenna)
// 3D printable enclosure, no supports needed
// Print: bottom + lid separately, flat side down
// =============================================================================

// --- Tolerances & print settings ---
tol       = 0.3;    // printer tolerance (adjust for your printer)
wall      = 2.0;    // wall thickness
floor_t   = 1.6;    // floor/ceiling thickness
post_d    = 5.0;    // mounting post diameter
screw_d   = 2.2;    // M2 screw hole diameter
snap_gap  = 0.2;    // lid snap-fit clearance

// --- NodeMCU v2 dimensions ---
nmc_l     = 49.0;   // length (USB to antenna end)
nmc_w     = 26.0;   // width
nmc_h     = 10.0;   // height with pins soldered underneath
nmc_pcb_t = 1.6;    // PCB thickness
nmc_usb_w = 8.0;    // micro-USB connector width
nmc_usb_h = 3.5;    // micro-USB connector height

// --- CC1101 module dimensions ---
cc_l      = 29.0;   // length (SMA end to opposite)
cc_w      = 20.0;   // width
cc_h      = 3.5;    // height (tallest component on PCB)
cc_pcb_t  = 1.0;    // PCB thickness
sma_d     = 6.5;    // SMA connector diameter (nut flats ~8mm)
sma_hole  = 8.0;    // SMA hole in wall (clearance for nut)

// --- Internal layout ---
gap       = 4.0;    // gap between NodeMCU and CC1101
wire_ch   = 3.0;    // wire channel depth

// --- Computed internal dimensions ---
int_l     = nmc_l + gap + cc_l + 2*tol;
int_w     = max(nmc_w, cc_w) + 2*tol;
int_h     = nmc_h + 2 + 2*tol;   // +2 for clearance above tallest component

// --- Computed external dimensions ---
ext_l     = int_l + 2*wall;
ext_w     = int_w + 2*wall;
ext_h_bot = floor_t + int_h;      // bottom half height
ext_h_lid = floor_t + 3;          // lid height (shallow)
lip_h     = 2.0;                  // lid inner lip height

// --- Vent hole settings ---
vent_w    = 1.5;
vent_gap  = 2.5;
vent_n    = 5;

// --- NodeMCU position (USB end at -X wall) ---
nmc_x     = wall + tol;
nmc_y     = wall + tol + (int_w - nmc_w)/2;

// --- CC1101 position (SMA end at +X wall) ---
cc_x      = wall + tol + nmc_l + gap;
cc_y      = wall + tol + (int_w - cc_w)/2;

// --- Mounting post positions ---
// NodeMCU: 4 corner posts, inset 2mm from edges
nmc_post_inset = 2.0;
nmc_posts = [
    [nmc_x + nmc_post_inset,               nmc_y + nmc_post_inset],
    [nmc_x + nmc_l - nmc_post_inset,       nmc_y + nmc_post_inset],
    [nmc_x + nmc_post_inset,               nmc_y + nmc_w - nmc_post_inset],
    [nmc_x + nmc_l - nmc_post_inset,       nmc_y + nmc_w - nmc_post_inset],
];

// CC1101: 2 posts on the non-SMA end
cc_post_inset = 2.0;
cc_posts = [
    [cc_x + cc_post_inset,                 cc_y + cc_post_inset],
    [cc_x + cc_post_inset,                 cc_y + cc_w - cc_post_inset],
];


// =============================================================================
// BOTTOM HALF
// =============================================================================
module bottom() {
    difference() {
        union() {
            // Main box
            difference() {
                // Outer shell
                cube([ext_l, ext_w, ext_h_bot]);

                // Inner cavity
                translate([wall, wall, floor_t])
                    cube([int_l, int_w, int_h + 1]);
            }

            // Mounting posts for NodeMCU
            for (p = nmc_posts) {
                translate([p[0], p[1], floor_t])
                    cylinder(d=post_d, h=3, $fn=20);
            }

            // Mounting posts for CC1101
            for (p = cc_posts) {
                translate([p[0], p[1], floor_t])
                    cylinder(d=post_d, h=nmc_h - cc_h + 1, $fn=20);
            }

            // Lid alignment rim (inner lip for lid to sit on)
            difference() {
                translate([wall - 0.5, wall - 0.5, ext_h_bot])
                    cube([int_l + 1, int_w + 1, lip_h]);
                translate([wall + 0.8, wall + 0.8, ext_h_bot - 0.1])
                    cube([int_l - 0.6, int_w - 0.6, lip_h + 0.2]);
            }
        }

        // --- Cutouts ---

        // Micro-USB port (NodeMCU, -X wall)
        translate([-0.1, nmc_y + nmc_w/2 - nmc_usb_w/2, floor_t + 3])
            cube([wall + 0.2, nmc_usb_w, nmc_usb_h]);

        // SMA antenna hole (CC1101, +X wall)
        translate([ext_l - wall - 0.1, cc_y + cc_w/2, floor_t + nmc_h - cc_h + cc_pcb_t + 1])
            rotate([0, 90, 0])
                cylinder(d=sma_hole, h=wall + 0.2, $fn=30);

        // Screw holes in mounting posts
        for (p = nmc_posts) {
            translate([p[0], p[1], -0.1])
                cylinder(d=screw_d, h=floor_t + 4, $fn=16);
        }
        for (p = cc_posts) {
            translate([p[0], p[1], -0.1])
                cylinder(d=screw_d, h=floor_t + nmc_h, $fn=16);
        }

        // Bottom ventilation slots
        translate([ext_l/2 - (vent_n*(vent_w + vent_gap))/2, ext_w/2 - 10, -0.1])
            for (i = [0:vent_n-1])
                translate([i * (vent_w + vent_gap), 0, 0])
                    cube([vent_w, 20, floor_t + 0.2]);

        // Side ventilation slots (both long sides)
        for (side = [0, ext_w - wall]) {
            translate([ext_l/2 - (vent_n*(vent_w + vent_gap))/2, side - 0.1, floor_t + int_h/2 - 5])
                for (i = [0:vent_n-1])
                    translate([i * (vent_w + vent_gap), 0, 0])
                        cube([vent_w, wall + 0.2, 10]);
        }

        // Round the top edges (cosmetic chamfer)
        // (skipped for printability — add fillets in slicer if desired)
    }
}


// =============================================================================
// LID
// =============================================================================
module lid() {
    difference() {
        union() {
            // Top plate
            cube([ext_l, ext_w, floor_t]);

            // Inner lip that fits inside the bottom rim
            translate([wall + 0.8 + snap_gap, wall + 0.8 + snap_gap, floor_t])
                cube([int_l - 0.6 - 2*snap_gap, int_w - 0.6 - 2*snap_gap, lip_h - 0.2]);
        }

        // Top ventilation slots
        translate([ext_l/2 - (vent_n*(vent_w + vent_gap))/2, ext_w/2 - 10, -0.1])
            for (i = [0:vent_n-1])
                translate([i * (vent_w + vent_gap), 0, 0])
                    cube([vent_w, 20, floor_t + 0.2]);

        // Label recess (optional: for a printed label)
        translate([ext_l/2 - 15, ext_w/2 - 5, -0.1])
            cube([30, 10, 0.4]);
    }
}


// =============================================================================
// ASSEMBLY PREVIEW / PRINT LAYOUT
// =============================================================================

// Set to "preview" to see assembled, "print" for print layout
mode = "print";  // "preview" or "print"

if (mode == "preview") {
    // Assembled view
    color("DarkSlateGray") bottom();
    color("SlateGray", 0.5) translate([0, 0, ext_h_bot + lip_h + 5])
        lid();

    // Ghost boards for reference
    color("green", 0.3) translate([nmc_x, nmc_y, floor_t + 3])
        cube([nmc_l, nmc_w, nmc_pcb_t]);
    color("green", 0.3) translate([cc_x, cc_y, floor_t + nmc_h - cc_h + 1])
        cube([cc_l, cc_w, cc_pcb_t]);

} else {
    // Print layout — both parts flat, side by side
    bottom();
    translate([ext_l + 10, 0, 0])
        lid();
}


// =============================================================================
// DIMENSIONS (for reference)
// =============================================================================
// Uncomment to print dimensions to console:
// echo(str("External: ", ext_l, " x ", ext_w, " x ", ext_h_bot + floor_t + lip_h, " mm"));
// echo(str("Internal: ", int_l, " x ", int_w, " x ", int_h, " mm"));
// echo(str("Lid height: ", ext_h_lid, " mm"));

// Theme.js — Catppuccin Mocha palette + design tokens for omarchy-software.
// Imported into every QML file as `import "Theme.js" as T`.
//
// Spacing scale: 4, 8, 12, 16, 20, 24, 32 px
// Radius: 4 (small), 8 (medium), 12 (large)
// Typography: 11 caption, 12 small, 13 body, 14 subhead, 16 headline, 20 title
.pragma library

var Theme = {
    mode: "dark",

    // Surfaces (top → bottom)
    background:        "#1e1e2e",
    surface:           "#232336",   // cards, panels
    surface_elevated:  "#2a2a40",   // hovered cards, popovers
    surface_strong:    "#313145",   // selected, active
    overlay:           "#11111b",   // modal backdrop
    divider:           "#3a3a52",   // 1px lines, subtle borders

    // Foregrounds
    foreground:        "#cdd6f4",   // primary text
    foreground_muted:  "#a6adc8",   // secondary text
    foreground_dim:    "#7f849c",   // tertiary / placeholder
    foreground_subtle: "#585b70",   // very dim, captions

    // Accents
    accent:            "#89b4fa",   // primary blue — focus, links, tabs
    accent_hover:      "#b4cdff",
    success:           "#a6e3a1",   // green — install, ok
    warning:           "#f9e2af",   // yellow — caution
    danger:            "#f38ba8",   // red — remove, error
    info:              "#94e2d5",   // cyan — info

    // Source colours
    source_repo:       "#89b4fa",   // blue
    source_aur:        "#cba6f7",   // mauve
    source_cachyos:    "#94e2d5",   // teal

    // Semantic
    selection_bg:      "#313145",
    selection_text:    "#ffffff",

    // ── Spacing (use these — never hardcode px in QML) ──────────────────────────
    space_xs:          4,
    space_sm:          8,
    space_md:          12,
    space_lg:          16,
    space_xl:          24,
    space_xxl:         32,

    // ── Radius ─────────────────────────────────────────────────────────────────
    radius_sm:         4,
    radius_md:         6,
    radius_lg:         8,
    radius_xl:         12,

    // ── Typography ─────────────────────────────────────────────────────────────
    font_family:       "Inter, Cantarell, sans-serif",

    // Pixel sizes
    caption_size:      11,
    small_size:        12,
    body_size:         13,
    subhead_size:      14,
    headline_size:     16,
    title_size:        20,

    // Weights
    weight_normal:     Font.Normal,
    weight_medium:     Font.Medium,
    weight_bold:       Font.Bold,

    // ── Component sizes ────────────────────────────────────────────────────────
    titlebar_height:   44,
    tabbar_height:     40,
    row_height_sm:     32,
    row_height_md:     40,
    row_height_lg:     48,
    input_height:      36,
    button_height:     32,
    chip_height:       24,
    badge_height:      20,
    scrollbar_width:   8,

    // ── Misc ───────────────────────────────────────────────────────────────────
    glass:             "rgba(30,30,46,0.82)",
    shadow:            "#000000",
};

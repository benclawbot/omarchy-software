import QtQuick 2.15

// Theme — design tokens. Use as `Theme.color` everywhere.
// Spacing scale: 4, 8, 12, 16, 20, 24, 32 px
// Radius: 4, 6, 8, 12 px
// Typography: 11 caption, 12 small, 13 body, 14 subhead, 16 headline, 20 title
QtObject {
    // Surfaces
    readonly property color background:        "#1e1e2e"
    readonly property color surface:           "#232336"
    readonly property color surface_elevated:  "#2a2a40"
    readonly property color surface_strong:    "#313145"
    readonly property color overlay:           "#11111b"
    readonly property color divider:           "#3a3a52"

    // Foregrounds
    readonly property color foreground:        "#cdd6f4"
    readonly property color foreground_muted:  "#a6adc8"
    readonly property color foreground_dim:    "#7f849c"
    readonly property color foreground_subtle: "#585b70"

    // Accents
    readonly property color accent:            "#89b4fa"
    readonly property color accent_hover:      "#b4cdff"
    readonly property color success:           "#a6e3a1"
    readonly property color warning:           "#f9e2af"
    readonly property color danger:            "#f38ba8"
    readonly property color info:              "#94e2d5"

    // Source colours
    readonly property color source_repo:       "#89b4fa"
    readonly property color source_aur:        "#cba6f7"
    readonly property color source_cachyos:    "#94e2d5"

    // ── Spacing ────────────────────────────────────────────────────────────────
    readonly property int space_xs:            4
    readonly property int space_sm:            8
    readonly property int space_md:            12
    readonly property int space_lg:            16
    readonly property int space_xl:            24
    readonly property int space_xxl:           32

    // ── Radius ─────────────────────────────────────────────────────────────────
    readonly property int radius_sm:           4
    readonly property int radius_md:           6
    readonly property int radius_lg:           8
    readonly property int radius_xl:           12

    // ── Typography ─────────────────────────────────────────────────────────────
    readonly property string font_family:      "Inter, Cantarell, sans-serif"
    readonly property int caption_size:        11
    readonly property int small_size:          12
    readonly property int body_size:           13
    readonly property int subhead_size:        14
    readonly property int headline_size:       16
    readonly property int title_size:          20

    readonly property int weight_normal:       Font.Normal
    readonly property int weight_medium:       Font.Medium
    readonly property int weight_bold:         Font.Bold

    // ── Component sizes ────────────────────────────────────────────────────────
    readonly property int titlebar_height:     56
    readonly property int tabbar_height:       40
    readonly property int row_height_sm:       32
    readonly property int row_height_md:       40
    readonly property int row_height_lg:       48
    readonly property int input_height:        36
    readonly property int button_height:       32
    readonly property int chip_height:         24
    readonly property int badge_height:        20
}

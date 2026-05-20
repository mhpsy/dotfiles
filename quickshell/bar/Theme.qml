pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Global theme + tokens for the bar.
//
// Colors are sourced from ~/.config/quickshell/colors.json (rewritten by matugen
// on wallpaper change). FileView reads are ASYNC on this build (Quickshell 0.3.0
// / Qt 6.11) — read via onTextChanged / onLoaded, never via onFileChanged.text(),
// which latches the stale value.
//
// Naming: Material-you "on_surface" colors are exposed as `fgSurface`,
// `fgPrimary`, etc — QML parses any identifier matching /^on[A-Z]/ as a signal
// handler, so `onSurface` is unusable as a property name.
Singleton {
    id: theme

    // ---- typography ---------------------------------------------------------
    readonly property string uiFont:     "Fira Sans"
    // monospace family — used for the clock so HH:mm:ss digits have fixed
    // advance widths and the pill stops jittering as the second ticks. "JetBrains
    // Mono" is widely installed; falls back to "monospace" otherwise.
    readonly property string monoFont:   "JetBrains Mono"
    readonly property string glyphFont:  "Font Awesome 7 Free"
    readonly property string glyphStyle: "Solid"

    // ---- sizing -------------------------------------------------------------
    // Single source of truth for bar height. NEVER bind this to content — wlroots
    // reconfigures the layer surface on every change, causing per-frame jitter.
    // Sizes match the previous waybar: bar 36, pill 24 (=36 minus 6 vertical
    // margin each side), font 14, pill spacing 4, pill H-padding 8.
    readonly property int barHeight:      36
    readonly property int barTopMargin:    6
    readonly property int barSideMargin:   8
    readonly property int barInnerPad:    10
    readonly property int gapsOut:         8     // Hyprland general:gaps_out
    readonly property int pillHeight:     24
    readonly property int radius:         12
    readonly property int gap:             8
    readonly property int pad:             8

    // ---- typography sizing ---------------------------------------------------
    // Single base size — matches waybar's 14px default. Special "weather /
    // quotes" pills in waybar bumped to 15; we keep one size for consistency
    // across the bar (font-family differences already differentiate them).
    readonly property int textSize:  14
    readonly property int glyphSize: 14
    readonly property int clockSize: 14

    // ---- material-you palette ----------------------------------------------
    // Defaults match the current matugen output so first paint isn't black/empty
    // (FileView load is async). Overwritten by applyColors() once the file lands.
    property color primary:               "#adc6ff"
    property color primaryContainer:      "#2b4678"
    property color fgPrimaryContainer:    "#d8e2ff"
    property color secondary:             "#bfc6dc"
    property color secondaryContainer:    "#3f4759"
    property color fgSecondaryContainer:  "#dbe1f9"
    property color tertiary:              "#debcdf"
    property color tertiaryContainer:     "#583e5b"
    property color fgTertiaryContainer:   "#fbd7fc"
    property color surface:               "#111318"
    property color surfaceContainer:      "#1e1f25"
    property color surfaceContainerHigh:  "#282a2f"
    property color fgSurface:             "#e2e2e9"
    property color fgSurfaceVariant:      "#c4c6d0"
    property color outline:               "#8e9099"
    property color error:                 "#ffb4ab"

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onTextChanged: theme.applyColors()
        onLoaded:      theme.applyColors()
    }

    // matugen writes the file atomically (write-temp + rename). On some kernels
    // the inotify watch can miss the rename — a cheap 2s reload() is a safety
    // net; when the watch works, applyColors() is idempotent and the reload is
    // free.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: colorsFile.reload()
    }

    function applyColors() {
        const t = colorsFile.text()
        if (!t) return
        let c
        try { c = JSON.parse(t) } catch (_) { return }
        if (c.primary)                 theme.primary              = c.primary
        if (c.primary_container)       theme.primaryContainer     = c.primary_container
        if (c.on_primary_container)    theme.fgPrimaryContainer   = c.on_primary_container
        if (c.secondary)               theme.secondary            = c.secondary
        if (c.secondary_container)     theme.secondaryContainer   = c.secondary_container
        if (c.on_secondary_container)  theme.fgSecondaryContainer = c.on_secondary_container
        if (c.tertiary)                theme.tertiary             = c.tertiary
        if (c.tertiary_container)      theme.tertiaryContainer    = c.tertiary_container
        if (c.on_tertiary_container)   theme.fgTertiaryContainer  = c.on_tertiary_container
        if (c.surface)                 theme.surface              = c.surface
        if (c.surface_container)       theme.surfaceContainer     = c.surface_container
        if (c.surface_container_high)  theme.surfaceContainerHigh = c.surface_container_high
        if (c.on_surface)              theme.fgSurface            = c.on_surface
        if (c.on_surface_variant)      theme.fgSurfaceVariant     = c.on_surface_variant
        if (c.outline)                 theme.outline              = c.outline
        if (c.error)                   theme.error                = c.error
    }
}

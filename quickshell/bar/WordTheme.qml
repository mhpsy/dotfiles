pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: theme
    readonly property string uiFont: "Fira Sans"
    readonly property string glyphFont: "Font Awesome 7 Free"
    readonly property string glyphStyle: "Solid"
    // colors are #AARRGGBB (QML/Qt ARGB order - alpha first)
    readonly property color cardBg1: "#f7101016"
    readonly property color cardBg2: "#f70a0a0e"
    readonly property color stroke:  "#22ffffff"
    readonly property color fg:      "#ffffff"
    readonly property color fgDim:   "#8cffffff"
    readonly property color fgFaint: "#73ffffff"
    readonly property color accent:  "#cdd6ff"
    readonly property color chipBg:  "#10ffffff"
    readonly property int radius: 18

    // ---- live matugen palette ----------------------------------------------
    // matugen rewrites ~/.config/quickshell/colors.json on every theme/wallpaper
    // change; we watch it so the POS hero gradients re-theme automatically.
    // Fallbacks = the values currently shipped in that file, so the card never
    // goes blank if the file is briefly missing or half-written.
    property color mPrimary:   "#adc6ff"
    property color mSecondary: "#bfc6dc"
    property color mTertiary:  "#debcdf"
    property color mError:     "#ffb4ab"

    // Portable: resolve the config dir at runtime (no hardcoded username) so a
    // plain clone works on any machine / user. matugen writes colors.json here.
    readonly property string palPath: {
        var x = Quickshell.env("XDG_CONFIG_HOME")
        var base = (x && x.length) ? x : (Quickshell.env("HOME") + "/.config")
        return base + "/quickshell/colors.json"
    }

    FileView {
        id: pal
        path: theme.palPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: theme.applyPalette()
        onTextChanged: theme.applyPalette()
    }
    // Net for the missing-file-at-load case (inotify watch never attaches if the
    // file is absent when FileView loads) - same pattern as the state files.
    Timer { interval: 400; running: true; repeat: true; onTriggered: pal.reload() }

    function applyPalette() {
        try {
            var j = JSON.parse(pal.text())
            if (j.primary)   theme.mPrimary   = j.primary
            if (j.secondary) theme.mSecondary = j.secondary
            if (j.tertiary)  theme.mTertiary  = j.tertiary
            if (j.error)     theme.mError     = j.error
        } catch (e) { /* keep last-good / fallbacks */ }
    }

    // ---- POS -> theme color / label / mark ---------------------------------
    // posColor feeds the SATURATION reference (keeps the hero tied to the live
    // theme's vibrancy); posHue pins a DISTINCT hue per POS so v. and adj. never
    // collide even when the palette's primary/secondary are both blue.
    function posColor(p) {
        switch (p) {
            case "v.": case "vt.": case "vi.": return mPrimary
            case "n.":                          return mTertiary
            case "adj.": case "a.":             return mSecondary
            case "adv.": case "ad.":            return mError
            default:                            return mPrimary
        }
    }
    // hue in 0..1 (0=red .33=green .66=blue) - fixed per POS for guaranteed
    // separation: v.=blue  n.=purple  adj.=teal/green  adv.=warm red.
    function posHue(p) {
        switch (p) {
            case "v.": case "vt.": case "vi.": return 0.611   // ~220 blue
            case "n.":                          return 0.800   // ~288 purple
            case "adj.": case "a.":             return 0.452   // ~163 teal/green
            case "adv.": case "ad.":            return 0.028   // ~10  warm red
            default:                            return 0.611
        }
    }
    function posLabel(p) {
        switch (p) {
            case "v.": case "vt.": case "vi.": return "VERB"
            case "n.":                          return "NOUN"
            case "adj.": case "a.":             return "ADJECTIVE"
            case "adv.": case "ad.":            return "ADVERB"
            default:                            return (p || "").toUpperCase()
        }
    }
    // FA7 Free Solid "印记" glyph per POS. ASCII \uXXXX escapes - a literal PUA
    // char can be silently stripped by editing tooling (that bit the speak icon).
    function posGlyph(p) {
        switch (p) {
            case "v.": case "vt.": case "vi.": return "\uf04b"  // FA play    (ASCII-safe escape)
            case "n.":                          return "\uf3a5"  // FA gem     (ASCII-safe escape)
            case "adj.": case "a.":             return "\uf005"  // FA star    (ASCII-safe escape)
            case "adv.": case "ad.":            return "\uf04e"  // FA forward (ASCII-safe escape)
            default:                            return "\uf02d"  // FA book    (ASCII-safe escape)
        }
    }
    function posLabelArr(arr) {
        if (!arr || !arr.length) return ""
        var out = []
        for (var i = 0; i < arr.length; i++) out.push(posLabel(arr[i]))
        return out.join("  ·  ")
    }
    // Vivid hero color: distinct per-POS HUE, SATURATION nudged off the live
    // theme token, fixed LIGHTNESS for the bold 图#3 look.
    function vivid(tok, hue, light) {
        var s = Math.min(1.0, Math.max(tok.hslSaturation, 0.62) * 1.2)
        return Qt.hsla(hue, s, light, 1.0)
    }
    // Hero gradient stops. Single POS -> bright -> deep fade of its hue;
    // multi-POS -> a two-hue blend (pos[0] -> pos[1]) per 图#3 "一词多性".
    function heroA(arr) {
        var p0 = (arr && arr.length) ? arr[0] : ""
        return vivid(posColor(p0), posHue(p0), 0.52)
    }
    function heroB(arr) {
        var n = arr ? arr.length : 0
        if (n >= 2) return vivid(posColor(arr[1]), posHue(arr[1]), 0.44)
        var p0 = n ? arr[0] : ""
        return vivid(posColor(p0), posHue(p0), 0.30)
    }
}

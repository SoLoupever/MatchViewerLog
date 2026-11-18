local addonName, ns = ...

-- ====================================================
-- WIDGETS — petits composants UI partages du compagnon.
-- ====================================================

local W = ns.RegisterModule("Widgets", {})
ns.Widgets = W

-- Palettes plates (theme MVL) ; en theme Blizzard le bouton est natif.
W.SPEC = {
    default = { bg = { 0.14, 0.12, 0.18, 1 }, border = { 0.40, 0.30, 0.55, 1 }, small = true },
    green   = { bg = { 0.10, 0.20, 0.14, 1 }, border = { 0.35, 0.70, 0.45, 1 }, small = true },
    red     = { bg = { 0.28, 0.08, 0.08, 1 }, border = { 0.80, 0.30, 0.30, 1 }, small = true },
    purple  = { bg = { 0.20, 0.14, 0.28, 1 }, border = { 0.63, 0.38, 1.00, 1 }, small = true },
}

-- Bouton au theme de MVL (ns.MVL.Button). spec : voir W.SPEC.
function W.SmallBtn(parent, w, label, spec)
    return ns.MVL.Button(parent, label, w, 20, spec or W.SPEC.default)
end

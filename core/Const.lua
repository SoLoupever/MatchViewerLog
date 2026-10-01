local addonName, ns = ...

-- ====================================================
-- CONST — donnees pures partagees. Aucune logique.
-- La matrice force/faiblesse des types arrivera avec la
-- barre de filtres (Phase 2) pour etre verifiee au poste.
-- ====================================================

-- breedID -> libelle (repli si besoin ; le breed reel vient de
-- BattlePetBreedID via fonctionnalite/Breed.lua).
ns.BREED_NAMES = {
    nil, nil, "B/B", "P/P", "S/S", "H/H", "H/P", "P/S", "H/S", "P/B", "S/B", "H/B",
}

ns.NUM_PET_TYPES = 10

-- Icone de type memoisee : GetPetTypeTexture renvoie un fileID constant par
-- type. Evite de rappeler l'API a chaque ligne rafraichie/scrollee.
local typeIconCache = {}
function ns.TypeIcon(petType)
    if not petType then return nil end
    local tex = typeIconCache[petType]
    if tex then return tex end
    tex = GetPetTypeTexture and GetPetTypeTexture(petType) or nil
    if tex then typeIconCache[petType] = tex end
    return tex
end

-- Niveau max d'une mascotte de combat (valeur du jeu).
ns.MAX_PET_LEVEL = 25

-- Draconien : type utilise comme marqueur "cette equipe a un script".
ns.DRAGONKIN_TYPE = 2

-- Valeur speciale d'un slot aleatoire : "pioche dans la file d'XP".
-- (Les autres valeurs de slot aleatoire sont des types 1..10.)
ns.RANDOM_XP = "xp"

-- Table des forces/faiblesses (donnee fixe du jeu, pas de l'API).
-- Index type : 1 Humanoide, 2 Draconien, 3 Volant, 4 Mort-vivant,
-- 5 Bestiole, 6 Magique, 7 Elementaire, 8 Bete, 9 Aquatique, 10 Mecanique.

-- STRONG_AGAINST[X] = le type qui frappe FORT le type X (+50%).
ns.STRONG_AGAINST = { [1]=4, [2]=1, [3]=6, [4]=5, [5]=8, [6]=2, [7]=9, [8]=10, [9]=3, [10]=7 }

-- TOUGH_AGAINST[X] = le type qui RESISTE au type X (prend -33% de X).
ns.TOUGH_AGAINST  = { [1]=8, [2]=4, [3]=2, [4]=9, [5]=1, [6]=10, [7]=5, [8]=3, [9]=6, [10]=7 }

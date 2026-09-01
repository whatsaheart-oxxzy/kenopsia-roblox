--!nonstrict
-- SUPPLY CONFIG (01.09.2026) -- what the supply terminal says, costs and shows.
--
-- The wardrobe + requisition screens (docs/MENU-SHOP-UIUX-SPEC.md, reworked by
-- docs/MENU-SHOP-UIUX-INTEGRATION.md) are IN-FACILITY surfaces, so every
-- colour is the MACHINE set from docs/place/04-GUI.md verbatim -- the cold
-- cyan of MenuConfig belongs to the front door outside, and a third palette
-- does not exist. WHITE is reserved for the tab-selection streak alone, the
-- same way MenuConfig reserves it; the FIRE red and the crosshair bone never
-- appear here (Btn_FIRE/Btn_PUNCH and the hip crosshair own those two hexes,
-- and tests/supply.lua greps this file to keep it that way).
--
-- PURE and portable to Lua 5.1 (the MenuConfig / ProgressionRules rule): no
-- Roblox globals, no type annotations, no compound assignment, no generalized
-- iteration. Colours are hex strings; the client wraps Color3.fromHex.
-- tests/supply.lua proves every number and rule in this file offline.
--
-- HOW things move is FeelConfig's job (step grid, typewriter, flicker). This
-- file only says WHAT, HOW MUCH and WHERE.

local Supply = {}

-- PALETTE -- the machine set, verbatim ----------------------------------------
Supply.Palette = {
	BG = "020602", -- screen ground (machine screens)
	PLATE = "041005", -- boxed cells, tiles, icon cutouts
	GREEN = "78FFAA", -- headings, digits, active elements, first-order frames
	GREEN_SOFT = "8CE8AE", -- body text, status lines, second rank
	GREEN_DIM = "2E6B4A", -- inert text, greyed rows, second-order frames
	WHITE = "FFFFFF", -- THE TAB STREAK ONLY
}

-- RARITY FRAME LADDER ---------------------------------------------------------
-- The spec's escalation idea (stroke -> glow -> double frame) mapped onto the
-- DIEGETIC tiers the registry already uses -- standard/issue/clearance/
-- overseer, never RARE/EPIC/LEGENDARY. Colour per tier is intensity within
-- the existing phosphors; assigning real hues per tier is decision D-B and
-- stays a one-table edit here when it lands.
Supply.Rarity = {
	standard = { stroke = "2E6B4A", pulse = false, double = false },
	issue = { stroke = "8CE8AE", pulse = false, double = false },
	clearance = { stroke = "78FFAA", pulse = true, double = false },
	overseer = { stroke = "78FFAA", pulse = true, double = true },
}

-- CRATE ECONOMY ---------------------------------------------------------------
-- Keys are EARNED (WORK ORDER fragments roll up at the verdict,
-- ProgressionRules.FRAGMENTS_PER_KEY); nothing here is a price in anything
-- buyable. WEIGHTS are RELATIVE per rarity and only the rarities actually
-- present in the unowned pool count -- CrateRules.odds normalises over those,
-- so the MANIFEST modal always shows the truth of the current pool and can
-- never drift from a hand-maintained table.
Supply.Crate = {
	COST_KEYS = 1,
	REEL_LENGTH = 28, -- tiles in the client reel
	RESULT_INDEX = 24, -- where the server's result sits; late, with tail room
	WEIGHTS = {
		standard = 50,
		issue = 100,
		clearance = 25,
		overseer = 10,
	},
}

-- REVEAL TIMINGS (seconds) ----------------------------------------------------
-- The spec's DECRYPT choreography: anticipation shake, spin-reel with a hard
-- ease-out, settle, flash, then the typewriter name. SPIN_BONUS stretches the
-- spin for the rarer tiers (spec: "UNIQUE/LEGENDARY: langsameres Timing").
-- Worst case must stay well under a lobby wait -- tests cap it at 15 s.
Supply.Reveal = {
	SHAKE = 0.6,
	SPIN = 4.2,
	SETTLE = 0.5,
	FLASH = 0.25,
	HOLD = 0.8,
	SPIN_BONUS = {
		clearance = 1.2,
		overseer = 2.0,
	},
}

-- STRINGS -- machine voice: flat, imperative, SHOUTED -------------------------
Supply.Strings = {
	TITLE = "SUPPLY TERMINAL",
	TAB_WARDROBE = "WARDROBE",
	TAB_SUPPLY = "REQUISITION",
	BUTTON = "SUPPLY_",
	WALLET_KEYS = "CRATE KEYS",
	WALLET_FRAGMENTS = "FRAGMENTS",
	WHEEL = "EMOTE WHEEL",
	DECRYPT = "DECRYPT",
	ODDS = "MANIFEST",
	ODDS_TITLE = "DECRYPT MANIFEST",
	ODDS_NOTE = "CONTENT DRAWN FROM UNPROCESSED STOCK ONLY",
	NO_KEYS = "NO CRATE KEYS",
	EMPTY = "COLLECTION COMPLETE",
	CLAIM = "CLAIM",
	AGAIN = "DECRYPT AGAIN",
	SEALED = "SEALED",
	OFFLINE = "OFFLINE",
	ACQUIRE = "ACQUIRE",
	ASSIGN = "ASSIGN TO WHEEL",
	CLEAR = "CLEAR SLOT",
	PLAY = "PLAY",
	OWNED = "OWNED",
	ON_WHEEL = "ON WHEEL",
	SOURCE_DEFAULT = "STANDARD ISSUE",
	SOURCE_CRATE = "CRATE STOCK",
	SOURCE_ROBUX = "OVERSEER STOCK",
	SOURCE_CLEARANCE = "CLEARANCE REWARD",
	KEYS_FROM = "KEYS COME FROM WORK ORDERS",
	PRIVATE = "PRIVATE CYCLE",
	DECRYPTING = "DECRYPTING...",
	CLOSE = "CLOSE",
}

-- LAYOUT ----------------------------------------------------------------------
-- Authored against the same ~710 px reference height as every machine screen,
-- so the existing UIScale story carries these numbers untouched.
Supply.Layout = {
	PanelW = 920,
	PanelH = 560,
	RailW = 168,
	RailRowH = 44,
	RailPad = 10,
	HeaderH = 56,
	PillH = 30,
	PillGap = 8,
	WheelSlot = 52,
	WheelGap = 8,
	CardW = 150,
	CardH = 112,
	CardGap = 12,
	DetailW = 250,
	ReelTileW = 132,
	ReelTileH = 110,
	ReelGap = 10,
	TouchRowH = 48, -- >= 44 pt floor on phone/tablet
	ButtonW = 132,
	ButtonH = 40,
}

return Supply

LUAGUI_NAME = "kh2SoundtrackSwitcher"
LUAGUI_AUTH = "Leinxad"
LUAGUI_DESC = "Switch KH2FM between Custom, Classic and Remastered soundtracks"

-- KH2 Soundtrack Switcher for LuaBackend v5.0
-- Place this script in scripts/kh2/.
--
-- Soundtrack is selected via in-game button combos (requires a recognised game version):
--   Select + R2 + Square    ->  custom      (whatever mod is already installed at the live routes)
--   Select + R2 + Triangle  ->  classic     (PS2 classic audio)
--   Select + R2 + Circle    ->  remastered  (HD remastered audio)
-- The selection is saved to kh2_soundtrack_pack.txt in the resolved mod\kh2 folder
-- (next to the scd routes) and reapplied on each script load; defaults to (and
-- recreates the file with) "custom" if the file is missing, blank, or unrecognised.
--
-- Press F1 while the game is running to reload and re-apply the saved selection.
--
-- Switching mechanism: every scd covered by the Classic/Remastered patches lives in
-- the exact same folder as the live (default) route. Whichever variant is active has
-- no filename prefix; the parked variants sit alongside it with a numeric prefix
-- (10 = custom, 20 = classic, 30 = remastered). Switching from A to B renames the live
-- file to add A's prefix, then renames B's prefixed file to the live filename. Disk is
-- assumed to already be arranged for the saved selection (it was left that way by the
-- last switch), so on load the switcher just adopts that selection — no renames happen
-- until the next combo press.

-- In-game button combos (PS bitmask: Select=0x0001, R2=0x0200, Square=0x0080, Triangle=0x1000, Circle=0x2000)
local COMBO_CUSTOM     = 0x0281  -- Select+R2+Square
local COMBO_CLASSIC    = 0x1201  -- Select+R2+Triangle
local COMBO_REMASTERED = 0x2201  -- Select+R2+Circle

-- Numeric filename prefix used to "park" each non-active variant.
local PREFIXES = { custom = "10", classic = "20", remastered = "30" }

-- Every scd route covered by the Classic/Remastered patches, relative to mod\kh2.
-- Extracted from the built (non-switcher) kh2-Classic.kh2pcpatch/kh2-Remastered.kh2pcpatch.
local ROUTES = {
    { dir = "kh2_fifth/original/bgm", file = "music050.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music051.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music052.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music053.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music054.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music055.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music059.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music060.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music061.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music062.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music063.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music064.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music065.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music066.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music067.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music068.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music069.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music081.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music084.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music085.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music086.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music087.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music088.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music089.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music090.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music091.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music092.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music093.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music094.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music095.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music096.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music097.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music098.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music099.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music100.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music101.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music102.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music103.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music104.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music106.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music107.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music108.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music109.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music110.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music111.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music112.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music113.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music114.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music115.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music116.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music117.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music120.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music121.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music122.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music123.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music124.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music125.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music127.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music128.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music129.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music130.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music131.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music132.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music133.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music134.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music135.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music136.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music137.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music138.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music139.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music141.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music142.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music143.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music144.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music145.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music146.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music148.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music149.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music151.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music152.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music153.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music154.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music155.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music158.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music159.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music164.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music185.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music186.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music187.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music188.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music189.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music190.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music506.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music507.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music508.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music509.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music513.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music517.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music521.win32.scd" },
    { dir = "kh2_fifth/original/bgm", file = "music530.win32.scd" },
    { dir = "kh2_first/original/bgm", file = "music082.win32.scd" },
    { dir = "kh2_first/original/bgm", file = "music118.win32.scd" },
    { dir = "kh2_first/original/bgm", file = "music119.win32.scd" },
    { dir = "kh2_first/original/vagstream", file = "Title.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "End_Piano.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "GM1_Asteroid.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "GM2_Highway.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "GM3_Cloud.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "GM4_Floating.win32.scd" },
    { dir = "kh2_sixth/original/vagstream", file = "GM5_Senkan.win32.scd" },
}

local filesDir         = nil
local canExecute       = false
local inputAddress     = nil
local currentSelection = "custom"
local lastInput        = 0

-- Save file lives in the resolved mod\kh2 folder, alongside the scd routes.
local function SaveFilePath()
    if not filesDir then return nil end
    return filesDir .. "\\kh2_soundtrack_pack.txt"
end

-- Persist the current selection to the save file.
local function SaveSelection(selection)
    local path = SaveFilePath()
    if not path then return end
    local f = io.open(path, "w")
    if f then
        f:write(selection)
        f:close()
    end
end

-- Read the saved selection from the save file. If the file is missing, blank,
-- or holds an unrecognised value, (re)create it with "custom" as the default.
local function LoadOrInitSelection()
    local path = SaveFilePath()
    local f = path and io.open(path, "r")
    local selection = f and f:read("*l") or nil
    if f then f:close() end
    if selection then selection = selection:match("^%s*(.-)%s*$") end
    if not selection or selection == "" or not PREFIXES[selection] then
        selection = "custom"
        SaveSelection(selection)
    end
    return selection
end

local function FileExists(path)
    local f = io.open(path, "rb")
    if f then
        f:close()
        return true
    end
    return false
end

-- Read the mod_path=... line out of panacea_settings.txt in the game's cwd,
-- strip its last path segment to get the OpenKH install dir, then append
-- \mod\<gameSubdir> to get the folder that holds this game's scd routes.
local function ResolveFilesDir(gameSubdir)
    local f = io.open(".\\panacea_settings.txt", "r")
    if not f then
        return nil
    end
    local modPath = nil
    for line in f:lines() do
        local key, val = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        if key == "mod_path" and val and val ~= "" then
            modPath = val
        end
    end
    f:close()
    if not modPath then
        return nil
    end
    local openkhDir = modPath:match("^(.*)\\[^\\]+$")
    if not openkhDir then
        return nil
    end
    return openkhDir .. "\\mod\\" .. gameSubdir
end

-- route.dir's first two segments (kh2_first/kh2_fifth/kh2_sixth/... and
-- "original") are metadata for the patch format only — OpenKH strips both
-- when installing, so the file actually lands two levels up (e.g.
-- mod\kh2\bgm\..., not mod\kh2\kh2_fifth\original\bgm\...). Drop them
-- before touching disk.
local function RouteBase(route)
    local subdir = route.dir:match("^[^/]+/[^/]+/(.*)$") or route.dir
    return filesDir .. "\\" .. subdir:gsub("/", "\\") .. "\\"
end

-- Switch every route from currentSelection to newSelection by renaming the
-- live file to park it under currentSelection's prefix, then promoting
-- newSelection's parked file (stripping its prefix) into the live slot.
-- Routes whose target file is missing are left untouched.
local function ApplySoundtrack(newSelection)
    if not filesDir or newSelection == currentSelection then
        return
    end
    local oldPrefix = PREFIXES[currentSelection]
    local newPrefix = PREFIXES[newSelection]
    local anySwitched = false
    for _, route in ipairs(ROUTES) do
        local base       = RouteBase(route)
        local livePath   = base .. route.file
        local targetPath = base .. newPrefix .. route.file
        if FileExists(targetPath) then
            if FileExists(livePath) then
                os.rename(livePath, base .. oldPrefix .. route.file)
            end
            os.rename(targetPath, livePath)
            anySwitched = true
        end
    end
    if anySwitched then
        currentSelection = newSelection
        SaveSelection(newSelection)
    end
end

function _OnInit()
    if GAME_ID == 0x431219CC and ENGINE_TYPE == "BACKEND" then
        filesDir = ResolveFilesDir("kh2")

        -- KH2FM Version Detection
        -- Fingerprint addresses hold 0x6A ('j') in their respective build.
        -- SteamGlobal 1.0.0.1 and SteamJP 1.0.0.2 share the same fingerprint address
        -- but differ in inputAddress; a secondary byte at 0x9A9330 disambiguates them
        -- (value 75 = 'K' is present only in the SteamGlobal 1.0.0.1 build).
        -- Columns: { fingerprint_off, inputAddr_off, disambig_off, disambig_val, label }
        canExecute   = false
        inputAddress = nil
        local versions = {
            { 0x660E04, 0x29FAE00, nil,      nil, "EGSGlobal 1.0.0.9"     },
            { 0x660E44, 0x29FAE40, nil,      nil, "EGSGlobal/JP 1.0.0.10" },
            { 0x65E898, 0x29F8AC0, nil,      nil, "EGSJP 1.0.0.9"         },
            { 0x660E74, 0x8BB250,  0x9A9330, 75,  "SteamGlobal 1.0.0.1"   },
            { 0x660EF4, 0x8BB2C0,  nil,      nil, "SteamGlobal 1.0.0.2"   },
            { 0x65FDF4, 0x8BA250,  nil,      nil, "SteamJP 1.0.0.1"       },
            { 0x660E74, 0x8BB2C0,  nil,      nil, "SteamJP 1.0.0.2"       },
        }
        for _, v in ipairs(versions) do
            if ReadByte(v[1]) == 0x6A then
                if v[3] == nil or ReadByte(v[3]) == v[4] then
                    inputAddress = v[2]
                    canExecute   = true
                    break
                end
            end
        end

        if canExecute then
            currentSelection = LoadOrInitSelection()
        end
    end
end

function _OnFrame()
    if canExecute then
        local input = ReadShort(inputAddress)
        if input == COMBO_CUSTOM and lastInput ~= COMBO_CUSTOM then
            ApplySoundtrack("custom")
        elseif input == COMBO_CLASSIC and lastInput ~= COMBO_CLASSIC then
            ApplySoundtrack("classic")
        elseif input == COMBO_REMASTERED and lastInput ~= COMBO_REMASTERED then
            ApplySoundtrack("remastered")
        end
        lastInput = input
    end
end

LUAGUI_NAME = "kh1SoundtrackSwitcher"
LUAGUI_AUTH = "Leinxad"
LUAGUI_DESC = "Switch KH1FM between Custom, Classic and Remastered soundtracks"

-- KH1 Soundtrack Switcher for LuaBackend v5.0
-- Place this script in scripts/kh1/.
--
-- Soundtrack is selected via in-game button combos (requires a recognised game version):
--   Select + R2 + Square    ->  custom      (whatever mod is already installed at the live routes)
--   Select + R2 + Triangle  ->  classic     (PS2 classic audio)
--   Select + R2 + Circle    ->  remastered  (HD remastered audio)
-- The selection is saved to kh1_soundtrack_pack.txt in the resolved mod\kh1 folder
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

-- Every scd route covered by the Classic/Remastered patches, relative to mod\kh1.
-- Extracted from the built (non-switcher) kh1-Classic.kh1pcpatch/kh1-Remastered.kh1pcpatch.
local ROUTES = {
    { dir = "kh1_first/remastered/amusic/music102.dat", file = "music102.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music104.dat", file = "music104.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music105.dat", file = "music105.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music106.bgm", file = "music106.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music107.bgm", file = "music107.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music108.bgm", file = "music108.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music109.bgm", file = "music109.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music110.dat", file = "music110.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music119.dat", file = "music119.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music131.dat", file = "music131.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music132.bgm", file = "music132.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music142.bgm", file = "music142.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music143.bgm", file = "music143.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music145.bgm", file = "music145.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music160.bgm", file = "music160.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music168.bgm", file = "music168.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music172.bgm", file = "music172.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music178.bgm", file = "music178.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music188.bgm", file = "music188.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music189.bgm", file = "music189.win32.scd" },
    { dir = "kh1_first/remastered/amusic/music190.bgm", file = "music190.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music097.bgm", file = "music097.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music098.bgm", file = "music098.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music099.bgm", file = "music099.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music101.dat", file = "music101.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music103.bgm", file = "music103.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music103.dat", file = "music103.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music110.bgm", file = "music110.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music111.bgm", file = "music111.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music111.dat", file = "music111.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music112.dat", file = "music112.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music113.bgm", file = "music113.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music114.bgm", file = "music114.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music115.bgm", file = "music115.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music116.dat", file = "music116.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music117.dat", file = "music117.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music118.bgm", file = "music118.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music118.dat", file = "music118.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music120.bgm", file = "music120.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music120.dat", file = "music120.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music121.dat", file = "music121.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music122.dat", file = "music122.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music123.dat", file = "music123.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music124.dat", file = "music124.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music125.dat", file = "music125.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music126.bgm", file = "music126.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music127.dat", file = "music127.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music128.dat", file = "music128.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music129.dat", file = "music129.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music130.dat", file = "music130.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music140.dat", file = "music140.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music141.dat", file = "music141.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music143.dat", file = "music143.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music144.dat", file = "music144.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music146.dat", file = "music146.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music147.dat", file = "music147.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music148.dat", file = "music148.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music149.dat", file = "music149.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music150.bgm", file = "music150.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music151.bgm", file = "music151.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music152.dat", file = "music152.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music153.dat", file = "music153.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music154.dat", file = "music154.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music155.dat", file = "music155.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music156.bgm", file = "music156.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music157.bgm", file = "music157.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music157.dat", file = "music157.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music158.bgm", file = "music158.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music159.bgm", file = "music159.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music161.bgm", file = "music161.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music162.bgm", file = "music162.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music163.bgm", file = "music163.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music164.bgm", file = "music164.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music165.bgm", file = "music165.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music166.bgm", file = "music166.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music167.bgm", file = "music167.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music169.bgm", file = "music169.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music170.bgm", file = "music170.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music171.bgm", file = "music171.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music173.bgm", file = "music173.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music174.bgm", file = "music174.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music175.bgm", file = "music175.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music176.bgm", file = "music176.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music177.bgm", file = "music177.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music179.bgm", file = "music179.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music180.bgm", file = "music180.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music181.bgm", file = "music181.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music182.bgm", file = "music182.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music183.bgm", file = "music183.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music184.bgm", file = "music184.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music184.dat", file = "music184.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music185.bgm", file = "music185.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music186.bgm", file = "music186.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music187.bgm", file = "music187.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music191.bgm", file = "music191.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music192.bgm", file = "music192.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music193.bgm", file = "music193.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music194.bgm", file = "music194.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music196.bgm", file = "music196.win32.scd" },
    { dir = "kh1_second/remastered/amusic/music197.bgm", file = "music197.win32.scd" },
}

local filesDir         = nil
local canExecute       = false
local inputAddress     = nil
local currentSelection = "custom"
local lastInput        = 0

-- Save file lives in the resolved mod\kh1 folder, alongside the scd routes.
local function SaveFilePath()
    if not filesDir then return nil end
    return filesDir .. "\\kh1_soundtrack_pack.txt"
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

-- route.dir's leading segment (kh1_first/kh1_second/...) identifies which of
-- KH1's split game archives an override targets. It's metadata for the patch
-- format only — OpenKH strips it when installing, so the file actually lands
-- one level up (e.g. mod\kh1\remastered\amusic\..., not
-- mod\kh1\kh1_second\remastered\amusic\...). Drop it before touching disk.
local function RouteBase(route)
    local subdir = route.dir:match("^[^/]+/(.*)$") or route.dir
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
    if GAME_ID == 0xAF71841E and ENGINE_TYPE == "BACKEND" then
        filesDir = ResolveFilesDir("kh1")

        -- KH1FM Version Detection
        -- Fingerprint addresses hold 0x6A ('j') in their respective build.
        -- Columns: { fingerprintOff, inputAddrOff, label }
        canExecute   = false
        inputAddress = nil
        local versions = {
            { 0x46A822, 0x23413B4, "EGSGlobal 1.0.0.10"               },
            { 0x46A7A2, 0x2341334, "EGSGlobal 1.0.0.9"                },
            { 0x46726E, 0x233D034, "EGSGlobal/JP 1.0.0.8"             },
            { 0x46A802, 0x23413B4, "EGSJP 1.0.0.10"                   },
            { 0x4697A2, 0x2340334, "EGSJP 1.0.0.9"                    },
            { 0x4698D2, 0x23407B4, "SteamGlobal 1.0.0.2"              },
            { 0x469872, 0x23407B4, "SteamGlobal 1.0.0.1 / SteamJP 1.0.0.2" },
            { 0x4697F2, 0x23407B4, "SteamJP 1.0.0.1"                  },
        }
        for _, v in ipairs(versions) do
            if ReadByte(v[1]) == 0x6A then
                inputAddress = v[2]
                canExecute   = true
                break
            end
        end

        if canExecute then
            currentSelection = LoadOrInitSelection()
        end
    end
end

function _OnFrame()
    if canExecute then
        local input = ReadInt(inputAddress)
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

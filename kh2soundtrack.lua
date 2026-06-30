LUAGUI_NAME = "kh2SoundtrackSwitcher"
LUAGUI_AUTH = "Leinxad"
LUAGUI_DESC = "Switch KH2FM between Custom, Classic and Remastered soundtracks"

-- KH2 Soundtrack Switcher for LuaBackend v5.0
-- Place this script in scripts/kh2/.
--
-- Soundtrack is selected via in-game button combos (requires a recognised game version):
--   Select + R2 + Square    ->  custom      (OpenKH/modded audio  -> prefixes: bgm   / vagstream)
--   Select + R2 + Triangle  ->  classic     (PS2 classic audio    -> prefixes: bg2   / vagstrea2)
--   Select + R2 + Circle    ->  remastered  (HD remastered audio  -> prefixes: bg3   / vagstrea3)
-- Defaults to custom on each script load.
--
-- Press F1 while the game is running to reload and re-apply the default.

-- In-game button combos (PS bitmask: Select=0x0001, R2=0x0200, Square=0x0080, Triangle=0x1000, Circle=0x2000)
local COMBO_CUSTOM     = 0x0281  -- Select+R2+Square
local COMBO_CLASSIC    = 0x1201  -- Select+R2+Triangle
local COMBO_REMASTERED = 0x2201  -- Select+R2+Circle

-- Config file stores the last selected soundtrack so it persists across sessions.
local CONFIG_PATH = debug.getinfo(1, "S").source:match("@?(.*[/\\])") .. "kh2soundtrack.cfg"

local function LoadConfig()
    local f = io.open(CONFIG_PATH, "r")
    if f then
        local sel = f:read("*l")
        f:close()
        if sel == "custom" or sel == "classic" or sel == "remastered" then
            ConsolePrint("KH2FM: loaded config -> " .. sel)
            return sel
        end
    end
    return "custom"
end

local function SaveConfig(selection)
    local f = io.open(CONFIG_PATH, "w")
    if f then
        f:write(selection)
        f:close()
    else
        ConsolePrint("KH2FM: warning – could not write config to " .. CONFIG_PATH)
    end
end

-- Convert a Lua string to a null-terminated byte array for WriteArrayA.
local function StringToBytes(s)
    local t = {}
    for i = 1, #s do t[i] = s:byte(i) end
    t[#t + 1] = 0
    return t
end

-- Full replacement strings written to each address (null terminator added by StringToBytes).
local STRINGS = {
    custom = {
        vsb118 = "bgm/music118.vsb",
        music  = "bgm/music%03d.win32.scd",
        gummi1 = "vagstream/GM1_Asteroid.win32.scd",
        gummi2 = "vagstream/GM2_Highway.win32.scd",
        gummi3 = "vagstream/GM3_Cloud.win32.scd",
        gummi4 = "vagstream/GM4_Floating.win32.scd",
        gummi5 = "vagstream/GM5_Senkan.win32.scd",
        report = "vagstream/End_Piano.win32.scd",
        title  = "vagstream/Title.win32.scd",
    },
    classic = {
        vsb118 = "bg2/music118.vsb",
        music  = "bg2/music%03d.win32.scd",
        gummi1 = "vagstrea2/GM1_Asteroid.win32.scd",
        gummi2 = "vagstrea2/GM2_Highway.win32.scd",
        gummi3 = "vagstrea2/GM3_Cloud.win32.scd",
        gummi4 = "vagstrea2/GM4_Floating.win32.scd",
        gummi5 = "vagstrea2/GM5_Senkan.win32.scd",
        report = "vagstrea2/End_Piano.win32.scd",
        title  = "vagstrea2/Title.win32.scd",
    },
    remastered = {
        vsb118 = "bg3/music118.vsb",
        music  = "bg3/music%03d.win32.scd",
        gummi1 = "vagstrea3/GM1_Asteroid.win32.scd",
        gummi2 = "vagstrea3/GM2_Highway.win32.scd",
        gummi3 = "vagstrea3/GM3_Cloud.win32.scd",
        gummi4 = "vagstrea3/GM4_Floating.win32.scd",
        gummi5 = "vagstrea3/GM5_Senkan.win32.scd",
        report = "vagstrea3/End_Piano.win32.scd",
        title  = "vagstrea3/Title.win32.scd",
    },
}

local vsb118Addr = nil
local musicAddr  = nil
local gummi1Addr = nil
local gummi2Addr = nil
local gummi3Addr = nil
local gummi4Addr = nil
local gummi5Addr = nil
local reportAddr = nil
local titleAddr  = nil
local lastInput  = 0

local function ReadStr(addr, len)
    local bytes = ReadArrayA(addr, len)
    local s = ""
    for i = 1, #bytes do
        if bytes[i] == 0 then break end
        s = s .. string.char(bytes[i])
    end
    return s
end

-- Write the full replacement strings to all nine addresses.
local function WriteSoundtrack(selection)
    if not (vsb118Addr and musicAddr and gummi1Addr and gummi2Addr and gummi3Addr and
            gummi4Addr and gummi5Addr and reportAddr and titleAddr) then
        ConsolePrint("KH2FM: addresses not ready yet, combo ignored")
        return
    end
    local s = STRINGS[selection] or STRINGS.custom
    WriteArrayA(vsb118Addr, StringToBytes(s.vsb118))
    WriteArrayA(musicAddr,  StringToBytes(s.music))
    WriteArrayA(gummi1Addr, StringToBytes(s.gummi1))
    WriteArrayA(gummi2Addr, StringToBytes(s.gummi2))
    WriteArrayA(gummi3Addr, StringToBytes(s.gummi3))
    WriteArrayA(gummi4Addr, StringToBytes(s.gummi4))
    WriteArrayA(gummi5Addr, StringToBytes(s.gummi5))
    WriteArrayA(reportAddr, StringToBytes(s.report))
    WriteArrayA(titleAddr,  StringToBytes(s.title))
end

-- Apply a soundtrack selection: write bytes to memory and persist the choice.
local function ApplySoundtrack(selection)
    WriteSoundtrack(selection)
    SaveConfig(selection)
    ConsolePrint("KH2FM soundtrack -> " .. selection)
    if musicAddr then
        ConsolePrint("KH2FM: vsb118=\"" .. ReadStr(vsb118Addr, 40) .. "\"")
        ConsolePrint("KH2FM: music=\""  .. ReadStr(musicAddr,  40) .. "\"")
        ConsolePrint("KH2FM: gummi1=\"" .. ReadStr(gummi1Addr, 40) .. "\"")
        ConsolePrint("KH2FM: gummi2=\"" .. ReadStr(gummi2Addr, 40) .. "\"")
        ConsolePrint("KH2FM: gummi3=\"" .. ReadStr(gummi3Addr, 40) .. "\"")
        ConsolePrint("KH2FM: gummi4=\"" .. ReadStr(gummi4Addr, 40) .. "\"")
        ConsolePrint("KH2FM: gummi5=\"" .. ReadStr(gummi5Addr, 40) .. "\"")
        ConsolePrint("KH2FM: report=\"" .. ReadStr(reportAddr, 40) .. "\"")
        ConsolePrint("KH2FM: title=\""  .. ReadStr(titleAddr,  40) .. "\"")
    end
end

function _OnInit()
    if GAME_ID == 0x431219CC and ENGINE_TYPE == "BACKEND" then
        -- KH2FM Version Detection
        -- Fingerprint addresses hold 0x6A ('j') in their respective build.
        -- SteamGlobal 1.0.0.1 and SteamJP 1.0.0.2 share the same fingerprint address
        -- but differ in inputAddress; a secondary byte at 0x9A9330 disambiguates them
        -- (value 75 = 'K' is present only in the SteamGlobal 1.0.0.1 build).
        canExecute   = false
        inputAddress = nil
        -- Each entry: { fingerprint_off, inputAddr_off, disambig_off, disambig_val,
        --               vsb118Off, musicOff, gummi1Off, gummi2Off, gummi3Off, gummi4Off, gummi5Off, reportOff, titleOff,
        --               label }
        local versions = {
            { 0x660E04, 0x29FAE00, nil,      nil, nil,      nil,      nil,      nil,      nil,      nil,      nil,      nil,      nil,      "EGSGlobal 1.0.0.9"     },
            { 0x660E44, 0x29FAE40, nil,      nil, 0x5B1B38, 0x5B4E30, 0x5B5910, 0x5B5938, 0x5B5958, 0x5B5978, 0x5B59A0, 0x5B87F8, 0x5B8818, "EGSGlobal/JP 1.0.0.10" },
            { 0x65E898, 0x29F8AC0, nil,      nil, nil,      nil,      nil,      nil,      nil,      nil,      nil,      nil,      nil,      "EGSJP 1.0.0.9"         },
            { 0x660E74, 0x8BB250,  0x9A9330, 75,  0x5B1978, 0x5B4C70, 0x5B5750, 0x5B5778, 0x5B5798, 0x5B57B8, 0x5B57E0, 0x5B8628, 0x5B8648, "SteamGlobal 1.0.0.1"   },
            { 0x660EF4, 0x8BB2C0,  nil,      nil, 0x5B1978, 0x5B4C70, 0x5B5750, 0x5B5778, 0x5B5798, 0x5B57B8, 0x5B57E0, 0x5B8628, 0x5B8648, "SteamGlobal 1.0.0.2"   },
            { 0x65FDF4, 0x8BA250,  nil,      nil, 0x5B1978, 0x5B4C70, 0x5B5750, 0x5B5778, 0x5B5798, 0x5B57B8, 0x5B57E0, 0x5B8628, 0x5B8648, "SteamJP 1.0.0.1"       },
            { 0x660E74, 0x8BB2C0,  nil,      nil, 0x5B1978, 0x5B4C70, 0x5B5750, 0x5B5778, 0x5B5798, 0x5B57B8, 0x5B57E0, 0x5B8628, 0x5B8648, "SteamJP 1.0.0.2"       },
        }
        for _, v in ipairs(versions) do
            if ReadByte(v[1]) == 0x6A then
                if v[3] == nil or ReadByte(v[3]) == v[4] then
                    inputAddress = v[2]
                    canExecute   = true
                    ConsolePrint("KH2FM: " .. v[14])
                    -- If address offsets are known for this version, resolve them now.
                    -- Otherwise addresses remain nil and combos will be silently ignored.
                    if v[5] ~= nil then
                        vsb118Addr = BASE_ADDR + v[5]
                        musicAddr  = BASE_ADDR + v[6]
                        gummi1Addr = BASE_ADDR + v[7]
                        gummi2Addr = BASE_ADDR + v[8]
                        gummi3Addr = BASE_ADDR + v[9]
                        gummi4Addr = BASE_ADDR + v[10]
                        gummi5Addr = BASE_ADDR + v[11]
                        reportAddr = BASE_ADDR + v[12]
                        titleAddr  = BASE_ADDR + v[13]
                        ApplySoundtrack(LoadConfig())
                    end
                    break
                end
            end
        end
        if not canExecute then
            ConsolePrint("KH2FM: version not recognised – in-game controls disabled")
        end
    else
        ConsolePrint("KH2FM not detected, not running script")
    end
end

function _OnFrame()
    if canExecute and musicAddr then
        local input = ReadShort(inputAddress)
        if input ~= lastInput and input ~= 0 then
            ConsolePrint(string.format("KH2FM: input=0x%X", input))
        end
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
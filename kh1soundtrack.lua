LUAGUI_NAME = "kh1SoundtrackSwitcher"
LUAGUI_AUTH = "Leinxad"
LUAGUI_DESC = "Switch KH1FM between Custom, Classic and Remastered soundtracks"

-- KH1 Soundtrack Switcher for LuaBackend v5.0
-- Place this script in scripts/kh1/.
--
-- Soundtrack is selected via in-game button combos (requires a recognised game version):
--   Select + R2 + Square    ->  custom      (OpenKH/modded audio  -> prefix: amusic)
--   Select + R2 + Triangle  ->  classic     (PS2 classic audio    -> prefix: amusi2)
--   Select + R2 + Circle    ->  remastered  (HD remastered audio  -> prefix: amusi3)
-- Defaults to custom on each script load.
--
-- Press F1 while the game is running to reload and re-apply the default.

-- In-game button combos (PS bitmask: Select=0x0001, R2=0x0200, Square=0x0080, Triangle=0x1000, Circle=0x2000)
local COMBO_CUSTOM     = 0x0281  -- Select+R2+Square
local COMBO_CLASSIC    = 0x1201  -- Select+R2+Triangle
local COMBO_REMASTERED = 0x2201  -- Select+R2+Circle

-- Config file stores the last selected soundtrack so it persists across sessions.
local CONFIG_PATH = debug.getinfo(1, "S").source:match("@?(.*[/\\])") .. "kh1soundtrack.cfg"

local function LoadConfig()
    local f = io.open(CONFIG_PATH, "r")
    if f then
        local sel = f:read("*l")
        f:close()
        if sel == "custom" or sel == "classic" or sel == "remastered" then
            ConsolePrint("KH1FM: loaded config -> " .. sel)
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
        ConsolePrint("KH1FM: warning – could not write config to " .. CONFIG_PATH)
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
    custom     = { music = "amusic/music",  dive = "amusic",  title = "amusic/music110.dat"  },
    classic    = { music = "amusi2/music",  dive = "amusi2",  title = "amusi2/music110.dat"  },
    remastered = { music = "amusi3/music",  dive = "amusi3",  title = "amusi3/music110.dat"  },
}

local musicAddr  = nil
local diveAddr   = nil
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

-- Write the full replacement strings to all three addresses.
local function WriteSoundtrack(selection)
    if not (musicAddr and diveAddr and titleAddr) then
        ConsolePrint("KH1FM: addresses not ready yet, combo ignored")
        return
    end
    local s = STRINGS[selection] or STRINGS.custom
    WriteArrayA(musicAddr, StringToBytes(s.music))
    WriteArrayA(diveAddr,  StringToBytes(s.dive))
    WriteArrayA(titleAddr, StringToBytes(s.title))
end

-- Apply a soundtrack selection: write bytes to memory and persist the choice.
local function ApplySoundtrack(selection)
    WriteSoundtrack(selection)
    SaveConfig(selection)
    ConsolePrint("KH1FM soundtrack -> " .. selection)
    if musicAddr then
        ConsolePrint("KH1FM: music=\""  .. ReadStr(musicAddr, 32) .. "\"")
        ConsolePrint("KH1FM: dive=\""   .. ReadStr(diveAddr,  32) .. "\"")
        ConsolePrint("KH1FM: title=\""  .. ReadStr(titleAddr, 32) .. "\"")
    end
end

function _OnInit()
    if GAME_ID == 0xAF71841E and ENGINE_TYPE == "BACKEND" then
        -- KH1FM Version Detection
        -- Fingerprint addresses hold 0x6A ('j') in their respective build.
        -- Columns: { fingerprintOff, inputAddrOff, musicOff, diveOff, titleOff, label }
        canExecute   = false
        inputAddress = nil
        local versions = {
            { 0x46A822, 0x23413B4, 0x3E3810, 0x3EFE44, 0x415A80, "EGSGlobal 1.0.0.10"               },
            { 0x46A7A2, 0x2341334, nil, nil, nil, "EGSGlobal 1.0.0.9"                },
            { 0x46726E, 0x233D034, nil, nil, nil, "EGSGlobal/JP 1.0.0.8"             },
            { 0x46A802, 0x23413B4, nil, nil, nil, "EGSJP 1.0.0.10"                   },
            { 0x4697A2, 0x2340334, nil, nil, nil, "EGSJP 1.0.0.9"                    },
            { 0x4698D2, 0x23407B4, 0x3E2998, 0x3EEFFC, 0x414B30, "SteamGlobal 1.0.0.2"              },
            { 0x469872, 0x23407B4, 0x3E2998, 0x3EEFFC, 0x414B30, "SteamGlobal 1.0.0.1 / SteamJP 1.0.0.2" },
            { 0x4697F2, 0x23407B4, 0x3E2998, 0x3EEFFC, 0x414B30, "SteamJP 1.0.0.1"                  },
        }
        for _, v in ipairs(versions) do
            if ReadByte(v[1]) == 0x6A then
                inputAddress = v[2]
                canExecute   = true
                ConsolePrint("KH1FM: " .. v[6])
                -- If address offsets are known for this version, resolve them now
                -- (instant; no scan needed). Otherwise fall back to _OnFrame scan.
                if v[3] ~= nil then
                    musicAddr = BASE_ADDR + v[3]
                    diveAddr  = BASE_ADDR + v[4]
                    titleAddr = BASE_ADDR + v[5]
                    ApplySoundtrack(LoadConfig())
                end
                break
            end
        end
        if not canExecute then
            ConsolePrint("KH1FM: version not recognised – in-game controls disabled")
        end
    else
        ConsolePrint("KH1FM not detected, not running script")
    end
end

function _OnFrame()
    if canExecute and musicAddr then
        local input = ReadInt(inputAddress)
        if input ~= lastInput and input ~= 0 then
            ConsolePrint(string.format("KH1FM: input=0x%X", input))
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
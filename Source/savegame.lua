if save then return end  -- avoid loading twice the same module
save = {}  -- create a table to represent the module

import "CoreLibs/graphics"

local datastore <const> = playdate.datastore
local gfx <const> = playdate.graphics

local icons = gfx.imagetable.new("images/settings/modifier_icons")

save.data = {
    SAVE_VERSION = 3,
    -- keep space for all games, even the ones without highscore tracking!
    -- this saves us from doing a bunch of if checks when dealing with this
    highscore = {0,0,0,0},
    settings = {
        musicOn = true,
        allowMic = true,
        allowTilt = true,
        allowPass = true,
        simonStartLvl = 1,
        bombSeconds = 30,
        bombActionsPerPass = 3,
        debugOn = false,
    }
}

-- k = keys of save.data.settings in the order they should appear in settings menu
-- need to do this, since pairs() returns elements in random order
-- (this is kinda overengineered, probably should have just hard coded the options...)
-- s is the string displayed in settings.lua
-- list of options can use "options" for values and (optional) "optionsStr" for how to display these
-- integers can use min and max to bound values
save.settingsMetadata = {
    { k="musicOn", s="MUSIC" },
    { k="allowMic", s="SHOUT IT" },
    { k="allowTilt", s="TILT IT" },
    { k="allowPass", s="PASS IT" },
    { k="simonStartLvl", s="SIMON START", min=1, max=5 },
    { k="bombSeconds", s="BOMB TIME",
        options=   {     15,     23,     30,     42,      60,   0,    -1 },
        optionsStr={ "15 S", "23 S", "30 S", "42 S", "1 MIN", "?", "???" } 
    },
    { k="bombActionsPerPass", s="BOMB ACTIONS", min=1, max=10 },
    { k="debugOn", s="DEBUG" },
    -- { k="test", s="TEST", options={ 10, -10, 20, 0, 500, 1e7 } },
}

local function indexInArray(array, val)
    for i=1, #array do
        if array[i] == val then
            return i
        end
    end
    return 0
end

function save.write()
    datastore.write(save.data)
end

function save.load()
    local loadData = datastore.read()

    if loadData ~= nil then
        if loadData.SAVE_VERSION == nil then
            save.data.settings.musicOn = loadData.musicOn
            save.data.settings.debugOn = loadData.debugOn
            save.data.highscore[GAME_MODE.CRANKIT] = loadData.highscore
            save.write()
        elseif loadData.SAVE_VERSION == 1 then
            save.data.settings.musicOn = loadData.musicOn
            save.data.settings.debugOn = loadData.debugOn
            save.data.highscore = loadData.highscore
            save.write()
        elseif loadData.SAVE_VERSION == 2 then
            for k,v in pairs(loadData.settings) do
                save.data.settings[k] = v
            end
            save.data.highscore = loadData.highscore
            save.write()
        elseif loadData.SAVE_VERSION == save.data.SAVE_VERSION then
            save.data = loadData
        else
            assert(false, "Unknown save version: "..loadData.SAVE_VERSION)
        end
    end

    for _,v in ipairs(save.settingsMetadata) do
        if v.options == nil then goto continue end

        v.optionIndex = indexInArray(v.options, save.data.settings[v.k])
        -- Fix invalid values (not defined in options list)
        if v.optionIndex == 0 then
            v.optionIndex = 1
            save.data.settings[v.k] = v.options[1]
        end
        ::continue::
    end
end

function save.renderModifierIcons()
    local xPos = 364
    if not save.data.settings.allowPass then
        icons:drawImage(3, xPos, 4)
        xPos = xPos - 32
    end
    if not save.data.settings.allowTilt then
        icons:drawImage(2, xPos, 4)
        xPos = xPos - 32
    end
    if not save.data.settings.allowMic then
        icons:drawImage(1, xPos, 4)
        xPos = xPos - 32
    end
end
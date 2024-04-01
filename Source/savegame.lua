if save then return end  -- avoid loading twice the same module
save = {}  -- create a table to represent the module

local datastore <const> = playdate.datastore

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
        bombSeconds = 30,
        debugOn = false,
    }
}

-- k = keys of save.data.settings in the order they should appear in settings menu
-- need to do this, since pairs() returns elements in random order
-- (this is kinda overengineered, probably should have just hard coded the options...)
save.settingsMetadata = {
    { k="musicOn", s="MUSIC" },
    { k="allowMic", s="SHOUT IT" },
    { k="allowTilt", s="TILT IT" },
    { k="allowPass", s="PASS IT" },
    { k="bombSeconds", s="BOMB TIME",
        options=   {     15,     23,     30,     42,      60,     90,     120 },
        optionsStr={ "15 S", "23 S", "30 S", "42 S", "1 MIN", "90 S", "2 MIN" } 
    },
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

    if (save.data.settings.musicOn) then
        Statemachine.music:setVolume(1.0)
    else
        Statemachine.music:setVolume(0)
    end
end

function save.load()
    local loadData = datastore.read()

    if (loadData == nil) then return end

    -- convert from old save file
    if (loadData.SAVE_VERSION == nil) then
        save.data.settings.musicOn = loadData.musicOn
        save.data.settings.debugOn = loadData.debugOn
        save.data.highscore[GAME_MODE.CRANKIT] = loadData.highscore
        save.write()
    elseif (loadData.SAVE_VERSION == 1) then
        save.data.settings.musicOn = loadData.musicOn
        save.data.settings.debugOn = loadData.debugOn
        save.data.highscore = loadData.highscore
        save.write()
    elseif loadData.SAVE_VERSION == 2 then
        save.data = loadData
        save.data.settings.allowPass = true
        save.write()
    else
        save.data = loadData
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

    if (save.data.settings.musicOn) then
        Statemachine.music:setVolume(1.0)
    else
        Statemachine.music:setVolume(0)
    end
end
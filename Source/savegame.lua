if save then return end  -- avoid loading twice the same module
save = {}  -- create a table to represent the module

local datastore <const> = playdate.datastore

save.data = {
    SAVE_VERSION = 2,
    highscore = {0,0,0,0},
    settings = {
        musicOn = true,
        allowMic = true,
        allowTilt = true,
        bombSeconds = 60,
        debugOn = false,
    }
}

-- k = keys of save.data.settings in the order they should appear in settings menu
-- need to do this, since pairs() returns elements in random order
save.settingsMetadata = {
    { k="musicOn", s="MUSIC" },
    { k="allowMic", s="MICROPHONE" },
    { k="allowTilt", s="TILT" },
    { k="bombSeconds", s="BOMB TIME" },
    { k="debugOn", s="DEBUG" },
}

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
    if (loadData.SAVE_VERSION == 1) then
        save.data.settings.musicOn = loadData.musicOn
        save.data.settings.debugOn = loadData.debugOn
        save.write()
    elseif (loadData.SAVE_VERSION == nil) then
        save.data.settings.debugOn = loadData.debugOn
        save.data.settings.musicOn = loadData.musicOn
        save.data.settings.highscore[GAME_MODE.CRANKIT] = loadData.highscore
        save.write()
    else
        save.data = loadData
    end

    if (save.data.settings.musicOn) then
        Statemachine.music:setVolume(1.0)
    else
        Statemachine.music:setVolume(0)
    end

    -- Disable debug output for now (removed menu option)
    save.data.settings.debugOn = false
end
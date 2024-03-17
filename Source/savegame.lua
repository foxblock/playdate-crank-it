if save then return end  -- avoid loading twice the same module
save = {}  -- create a table to represent the module

local datastore <const> = playdate.datastore

save.data = {
    SAVE_VERSION = 2,
    highscore = {0,0,0,0},
    settings = {
        musicOn = true,
        debugOn = false,
        allowMic = true,
        allowTilt = true,
        bombSeconds = 60,
    }
}

-- keys of save.data.settings in the order they should appear in settings menu
-- need to do this, since pairs() returns elements in random order
save.settingsOrder = {
    "musicOn",
    "allowMic",
    "allowTilt",
    "bombSeconds",
}

-- label text for save.data.settings options in settings menu
save.settingsStrings = {
    musicOn = "MUSIC",
    debugOn = "DEBUG",
    allowMic = "MICROPHONE",
    allowTilt = "TILT",
    bombSeconds = "BOMB TIME",
}

function save.write()
    datastore.write(save.data)
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
        save.data.debugOn = loadData.debugOn
        save.data.musicOn = loadData.musicOn
        save.data.highscore[GAME_MODE.CRANKIT] = loadData.highscore
        save.write()
    else
        save.data = loadData
    end

    -- Disable debug output for now (removed menu option)
    save.data.debugOn = false
end
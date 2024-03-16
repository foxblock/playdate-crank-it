if save then return end  -- avoid loading twice the same module
save = {}  -- create a table to represent the module

local datastore <const> = playdate.datastore

save.data = {
    SAVE_VERSION = 1,
    highscore = {0,0,0,0},
    musicOn = true,
    debugOn = false
}

function save.write()
    datastore.write(save.data)
end

function save.load()
    local loadData = datastore.read()

    if (loadData == nil) then return end

    -- convert from old save file
    if (loadData.SAVE_VERSION == nil) then
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
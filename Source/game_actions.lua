if actions then return end  -- avoid loading twice the same module
actions = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/animation"
import "vec3d"

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput
local snd <const> = playdate.sound.sampleplayer

local TIME_FAST <const> = { 4000, 3000, 2000, 1300, 850 }
local TIME_NORMAL <const> = { 4000, 3000, 2200, 1600, 1200 }
local TIME_SLOW <const> = { 4000, 3200, 2500, 2000, 1750 }

local DEG_TO_RAD <const> = math.pi / 180
local RAD_TO_DEG <const> = 180 / math.pi

local CRANK_DEADZONE_NORMAL <const> = 45
local CRANK_DEADZONE_AFTER_CRANKED <const> = 360
local CRANK_TARGET <const> = 2*360
local MIC_LEVEL_TARGET <const> = 0.25 -- 0..1
local MIC_LEVEL_RESET <const> = 0.05
local MIC_RESET_FRAMES <const> = 5
local TILT_TARGET <const> = math.cos(75 * DEG_TO_RAD)


local crankValue = 0
local crankDeadzone = CRANK_DEADZONE_NORMAL
local startVec = nil
local micResetCounter = 0


actions.succesFnc = nil
actions.failFnc = nil
actions.current = nil

actions.codes = {
    BIG_HIGHSCORE = -4,
    STAR_HIGHSCORE = -3,
    HIGHSCORE = -2,
    LOSE_BOMB = -1,
    LOSE = 0,
    -- lose/end states above this line (will also no be selected automatically)
    DIRECTION = 1,
    BUTTON = 2,
    MICROPHONE = 3,
    TILT = 4,
    CRANK_UNDOCK = 5,
    CRANK_DOCK = 6,
    CRANKED = 7,
    _EOL = 8,
    -- everything below this line will not be automatically selected
    PASS_PLAYER = 9,
    SPEED_UP = 10,
    PASS_BOMB = 11,
}

-- TODO: Change snd entries from sampleplayer to sample and use one global player for all action sounds
actions.data = {
    [actions.codes.BIG_HIGHSCORE] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/big-highscore"),
        ani = gfx.imagetable.new("images/actions/highscore"),
    },
    [actions.codes.STAR_HIGHSCORE] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/star-highscore"),
        img = gfx.image.new("images/actions/highscore-static"),
    },
    [actions.codes.HIGHSCORE] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/highscore"),
        img = gfx.image.new("images/actions/highscore-static"),
    },
    [actions.codes.LOSE_BOMB] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/explosion"),
        img = gfx.image.new("images/actions/explode"),
    },
    [actions.codes.LOSE] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/lose"),
        img = gfx.image.new("images/actions/lose"),
    },
    [actions.codes.DIRECTION] = {
        time = TIME_FAST,
        snd = snd.new("sounds/move"),
        ani = gfx.imagetable.new("images/actions/move"),
        staticFrame = 2, -- for simon mode
        text = "MOV",
    },
    [actions.codes.BUTTON] = {
        time = TIME_FAST,
        snd = snd.new("sounds/press"),
        ani = gfx.imagetable.new("images/actions/press"),
        staticFrame = 3,
        text = "PRESS",
    },
    [actions.codes.MICROPHONE] = {
        time = TIME_FAST,
        snd = snd.new("sounds/shout"),
        img = gfx.image.new("images/actions/shout"),
        text = "SHOUT",
    },
    [actions.codes.TILT] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/tilt"),
        ani = gfx.imagetable.new("images/actions/tilt"),
        staticFrame = 2,
        text = "TILT",
    },
    [actions.codes.PASS_PLAYER] = {
        time = { 3000, 3000, 2500, 2500, 2000 },
        snd = snd.new("sounds/pass"),
        ani = gfx.imagetable.new("images/actions/pass"),
        staticFrame = 2,
        text = "PASS",
    },
    [actions.codes.CRANK_UNDOCK] = {
        time = TIME_NORMAL,
        snd = snd.new("sounds/undock"),
        img = gfx.image.new("images/actions/undock"),
        text = "UNDOCK",
    },
    [actions.codes.CRANK_DOCK] = {
        time = TIME_SLOW,
        snd = snd.new("sounds/dock"),
        img = gfx.image.new("images/actions/dock"),
        text = "DOCK",
    },
    [actions.codes.CRANKED] = {
        time = TIME_SLOW,
        snd = snd.new("sounds/crank"),
        ani = gfx.imagetable.new("images/actions/crank"),
        staticFrame = 1,
        text = "CRANK",
    },
    [actions.codes.SPEED_UP] = {
        time = { 2000, 2000, 2000, 2000, 2000 },
        snd = snd.new("sounds/speed"),
        img = gfx.image.new("images/actions/speed"),
        text = "HOLD",
    },
    [actions.codes.PASS_BOMB] = {
        time = { 2500, 2500, 2500, 2500, 2500 },
        snd = snd.new("sounds/pass"),
        ani = gfx.imagetable.new("images/bomb/pass"),
        staticFrame = 2,
        text = "PASS",
    },
}

local function failText(should, did)
    if should == nil or did == nil then return "" end

    return "YOU "..actions.data[did].text.."ED IT,\nINSTAED OF\n"..actions.data[should].text.."ING IT"
end

actions.buttonHandler = {
    upButtonDown = function()
        if (actions.current == actions.codes.DIRECTION) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.DIRECTION))
        end
    end,

    rightButtonDown = function()
        if (actions.current == actions.codes.DIRECTION) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.DIRECTION))
        end
    end,

    downButtonDown = function()
        if (actions.current == actions.codes.DIRECTION) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.DIRECTION))
        end
    end,

    leftButtonDown = function()
        if (actions.current == actions.codes.DIRECTION) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.DIRECTION))
        end
    end,

    AButtonDown = function()
        if (actions.current == actions.codes.BUTTON) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.BUTTON))
        end
    end,

    BButtonDown = function()
        if (actions.current == actions.codes.BUTTON) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.BUTTON))
        end
    end,

    crankDocked = function()
        if (actions.current == actions.codes.CRANK_DOCK) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.CRANK_DOCK))
        end
    end,

    crankUndocked = function()
        if (actions.current == actions.codes.CRANK_UNDOCK) then
            actions.succesFnc()
        else
            actions.failFnc(failText(actions.current, actions.codes.CRANK_UNDOCK))
        end
    end,

    cranked = function(change, acceleratedChange)
        -- Ignore when docking, since crank may need to be moved to do so
        if (actions.current == actions.codes.CRANK_DOCK) then return end

        crankValue = crankValue + math.abs(change)
        if (actions.current == actions.codes.CRANKED and crankValue >= CRANK_TARGET) then
            crankValue = 0
            actions.succesFnc()
        elseif (actions.current ~= actions.codes.CRANKED and crankValue >= crankDeadzone) then
            crankValue = 0
            actions.failFnc(failText(actions.current, actions.codes.CRANKED))
        end
    end
}

-- crankDocked override for simon gamemode (since actual crank might be different
-- from needed crank state at specific point in chain)
function actions.getValidActionCode(excludeOption, crankDocked)
    local result = 0
    if (crankDocked == nil) then
        crankDocked = playdate.isCrankDocked()
    end
    repeat
        if (crankDocked) then
            result = math.random(1, actions.codes.CRANK_UNDOCK)
        else
            result = math.random(1, actions.codes._EOL - 1)
        end
    -- exclude UNDOCK action when crank is undocked
    -- exclude MICROPHONE action on simulator without microphone input
    -- exclude disabled actions (as per settings)
    until ((crankDocked or result ~= actions.codes.CRANK_UNDOCK)
        and (not playdate.isSimulator or result ~= actions.codes.MICROPHONE)
        and (excludeOption == nil or result ~= excludeOption)
        and (save.data.settings.allowMic or result ~= actions.codes.MICROPHONE)
        and (save.data.settings.allowTilt or result ~= actions.codes.TILT)
    )

    return result
end

function actions.setupActionGameplay(last, curr)
    -- increase deadzone after CRANKED action, so turning the crank
    -- a bit too far does not immediately fail the player
    if (curr == actions.codes.CRANKED or last == actions.codes.CRANKED) then
        crankDeadzone = CRANK_DEADZONE_AFTER_CRANKED
    else
        crankDeadzone = CRANK_DEADZONE_NORMAL
    end
    -- always reset crank value, because it is checked for succeed and fail
    crankValue = 0

    if (curr == actions.codes.MICROPHONE) then
        mic.startListening()
    else
        mic.stopListening()
    end

    if (curr == actions.codes.TILT) then
        startVec = { vec3d.norm(playdate.readAccelerometer()) }
        -- print("TILT START")
        -- print(string.format("Angles: %.2f %.2f %.2f", playdate.readAccelerometer()))
        -- print(string.format("Norm: %.2f %.2f %.2f", startVec[1], startVec[2], startVec[3]))
    end
end

function actions.setupActionGfxAndSound(curr, static)
    if (actions.data[curr].ani ~= nil) then
        actions.data[curr].img.frame = static and actions.data[curr].staticFrame or 1
    end
    gfx.sprite.redrawBackground()
    actions.data[curr].snd:play(1)
end

-- return 1 on action success, 0 on no status change, -1 on action fail (currently no fail condition)
function actions.checkTilt()
    if (actions.current == actions.codes.TILT) then
        local cos_ang = vec3d.dot(startVec, playdate.readAccelerometer())
        if (cos_ang <= TILT_TARGET) then
            return 1
        end
    end
    return 0
end

-- return 1 on action success, 0 on no status change, -1 on action fail (currently no fail condition)
-- call on every frame (for reset logic)
function actions.checkMic()
    local level = mic.getLevel()

    if micResetCounter > 0 then
        if level < MIC_LEVEL_RESET then
            micResetCounter = micResetCounter - 1
        end
        return 0
    end

    if actions.current == actions.codes.MICROPHONE and level >= MIC_LEVEL_TARGET then
        micResetCounter = MIC_RESET_FRAMES
        return 1
    end

    return 0
end


function actions.renderDebugInfo(yPosStart)
    local yPos = yPosStart or 2
    if (actions.current == actions.codes.MICROPHONE) then
        gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
        yPos = yPos + 25
    elseif (actions.current == actions.codes.TILT) then
        gfx.drawText(string.format("val: %.2f %.2f %.2f", playdate.readAccelerometer()), 2, yPos);
        gfx.drawText(string.format("a3d: %.2f", math.acos(vec3d.dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, yPos + 15)
        gfx.drawText(string.format("cos: %.4f", vec3d.dot(startVec, playdate.readAccelerometer())), 2, yPos + 30)
        gfx.drawText(string.format("target: %.4f", TILT_TARGET), 2, yPos + 45)
        yPos = yPos + 70
    end
    return yPos
end

-- set up animations
-- actions with img set, keep that as a static background
-- actions with ani set (we assume it is a tilemap), will load it into img as an animation
-- actions with neither set will get an ERROR
local ACTION_ANIMATION_FRAME_TIME_MS <const> = 500
for k,v in pairs(actions.data) do
    if (v.img ~= nil) then
        goto continue
    elseif (v.ani ~= nil) then
        v.img = gfx.animation.loop.new(ACTION_ANIMATION_FRAME_TIME_MS, v.ani, true)
    else
        error("No image or animation defined for action: " .. k)
    end
    ::continue::
end
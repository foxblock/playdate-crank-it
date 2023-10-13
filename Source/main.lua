-- https://www.youtube.com/watch?v=ayBmsWKqdnc

-- Accelerometer
-- Values of readAccelerometer() = normal vector pointing from screen with device upright
--                                 in the following coordinate space
--      ^ z = 1
--      |
--      |
--      .-----> x = 1 (device needs to be tilted by 90° around x-axis)
--     /
--    /
--   v  y = 1

------ TODO
-- [X] action: pass to other player
-- [X] action: speed up
-- [X] default time value for individual actions (i.e. more time for dock/undock)
-- [X] multiply by speed factor
-- [X] lose on lock
-- [ ] game mode: last one cranking
-- [ ] game mode: simon cranks
-- [ ] title card
-- [ ] background animations for actions
-- [ ] sound for actions
-- [ ] background music
-- [ ] save highscore values


import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput
local v2d <const> = playdate.geometry.vector2D
local screen <const> = playdate.display

local RAD_TO_DEG <const> = 180 / math.pi
local DEG_TO_RAD <const> = math.pi / 180

local playerSprite = nil
local font = gfx.font.new('images/font/whiteglove-stroked')
assert(font)

local actionCodes <const> = {
    LOSE = 0,
    UP = 1,
    RIGHT = 2,
    DOWN = 3,
    LEFT = 4,
    A = 5,
    B = 6,
    MICROPHONE = 7,
    TILT = 8,
    PASS_PLAYER = 9,
    CRANK_UNDOCK = 10,
    CRANK_DOCK = 11,
    CRANKED = 12,
    EOL = 13, ----
    SPEED_UP = 14,
}

local timeFast <const> = { 4000, 3000, 2000, 1300, 700 }
local timeNormal <const> = { 4000, 3000, 2200, 1500, 1000 }
local timeSlow <const> = { 4000, 3200, 2500, 2000, 1500 }

local actions <const> = {
    [actionCodes.LOSE] = { msg = "You lose! (Press A to restart)", time = {} },
    [actionCodes.UP] = { msg = "Press UP", time = timeFast },
    [actionCodes.RIGHT] = { msg = "Press RIGHT", time = timeFast },
    [actionCodes.DOWN] = { msg = "Press DOWN", time = timeFast },
    [actionCodes.LEFT] = { msg = "Press LEFT", time = timeFast },
    [actionCodes.A] = { msg = "Press A", time = timeFast },
    [actionCodes.B] = { msg = "Press B", time = timeFast },
    [actionCodes.MICROPHONE] = { msg = "Blow in the microphone", time = timeFast },
    [actionCodes.TILT] = { msg = "Tilt it", time = timeNormal },
    [actionCodes.PASS_PLAYER] = { msg = "Pass it", time = { 3000, 2500, 2000, 1500, 1500 } },
    [actionCodes.CRANK_UNDOCK] = { msg = "Undock the Crank", time = timeNormal },
    [actionCodes.CRANK_DOCK] = { msg = "Dock the Crank", time = timeSlow },
    [actionCodes.CRANKED] = { msg = "Crank it!", time = timeSlow },
    [actionCodes.SPEED_UP] = { msg = "SPEED UP", time = { 2000, 2000, 2000, 2000, 2000 } }
}

local CRANK_TARGET <const> = 2*360
local CRANK_DEADZONE_NORMAL <const> = 45
local CRANK_DEADZONE_AFTER_CRANKED <const> = 360
local TILT_TARGET <const> = math.cos(50 * DEG_TO_RAD)
local TILT_TARGET_BACK <const> = math.cos(5 * DEG_TO_RAD)
local SPEED_UP_INTERVAL <const> = 10
local MAX_SPEED_LEVEL <const> = 5

local currAction = actionCodes.A
local actionDone = (currAction == nil)
local actionTimer = nil;
local speedLevel = 1
local score = 0
local highscore = 0

local crankValue = 0
local crankDeadzone = CRANK_DEADZONE_NORMAL
local startVec = nil
local tiltBack = false

-- UTILITY

local function vec3D_len(x, y, z)
    return math.sqrt(x*x + y*y + z*z)
end

local function vec3D_norm(x, y, z)
    local len = vec3D_len(x, y, z)
    return x/len, y/len, z/len
end

-- assumes v1 is a normalized 3D-vector stored as a table with 3 entries: {x,y,z}
local function vec3D_dot(v1, x2, y2, z2)
    return (v1[1] * x2 + v1[2] * y2 + v1[3] * z2) / vec3D_len(x2, y2, z2)
end

-- MAIN GAME

local function actionSuccess()
    actionDone = true
    score += 1
end

local function actionFail()
    if (score > highscore) then
        highscore = score
    end
    score = 0
    currAction = actionCodes.LOSE
    actionTimer:pause()
end

local function actionTimerEnd()
    if (currAction == actionCodes.PASS_PLAYER) then
        actionSuccess()
        return
    elseif (currAction == actionCodes.SPEED_UP) then
        actionDone = true
        return
    end

    actionFail()
end

local function setup()
    -- Set up the player sprite.
    -- The :setCenter() call specifies that the sprite will be anchored at its center.
    -- The :moveTo() call moves our sprite to the center of the display.

    -- local playerImage = gfx.image.new("images/player")
    -- assert( playerImage ) -- make sure the image was where we thought

    -- playerSprite = gfx.sprite.new( playerImage )
    -- playerSprite:moveTo( 200, 120 ) -- this is where the center of the sprite is placed; (200,120) is the center of the Playdate screen
    -- playerSprite:add() -- This is critical!

    -- We want an environment displayed behind our sprite.
    -- There are generally two ways to do this:
    -- 1) Use setBackgroundDrawingCallback() to draw a background image. (This is what we're doing below.)
    -- 2) Use a tilemap, assign it to a sprite with sprite:setTilemap(tilemap),
    --       and call :setZIndex() with some low number so the background stays behind
    --       your other sprites.

    local backgroundImage = gfx.image.new( "images/background" )
    assert( backgroundImage )

    gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            -- x,y,width,height is the updated area in sprite-local coordinates
            -- The clip rect is already set to this area, so we don't need to set it ourselves
            backgroundImage:draw( 0, 0 )
        end
    )

    math.randomseed(playdate.getSecondsSinceEpoch())

    playdate.startAccelerometer()

    playdate.setCrankSoundsDisabled(true)

    actionTimer = playdate.timer.new(actions[currAction].time[speedLevel], actionTimerEnd)
    actionTimer.discardOnCompletion = false
end

local function render()
    gfx.sprite.update()
    playdate.timer.updateTimers()

    gfx.fillRect(0, screen.getHeight() - 20, screen.getWidth() * actionTimer.timeLeft / actionTimer.duration, 20)

    gfx.setFont(font)

    local yPos = 2
    gfx.drawText('score: '..score, 2, yPos)
    gfx.drawText("HIGH: "..highscore, 2, yPos + 15)
    yPos += 40
    if (currAction == actionCodes.MICROPHONE) then
        gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, yPos)
        yPos += 25
    elseif (currAction == actionCodes.TILT) then
        gfx.drawText(string.format("a3d: %.2f", math.acos(vec3D_dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, yPos)
        gfx.drawText(string.format("cos: %.4f", vec3D_dot(startVec, playdate.readAccelerometer())), 2, yPos + 15)
        gfx.drawText(string.format("target: %.4f", tiltBack and TILT_TARGET_BACK or TILT_TARGET), 2, yPos + 30)
        yPos += 55
    end

    gfx.drawText(string.format("timer: %d", actionTimer.timeLeft), 2, yPos);
    gfx.drawTextAligned(actions[currAction].msg, 200, 120, kTextAlignment.center)
end

function playdate.update()
    if (currAction == actionCodes.MICROPHONE and mic.getLevel() > 0.5) then
        actionSuccess()
    end

    if (currAction == actionCodes.TILT) then
        local cos_ang = vec3D_dot(startVec, playdate.readAccelerometer())
        if (tiltBack and cos_ang >= TILT_TARGET_BACK) then 
            tiltBack = false
            actionSuccess()
        elseif (not tiltBack and cos_ang <= TILT_TARGET) then
            tiltBack = true
        end
    end

    -- other actions are handled in callbacks

    if (actionDone) then
        local lastAction = currAction

        if (speedLevel < MAX_SPEED_LEVEL and score == SPEED_UP_INTERVAL * speedLevel) then
            currAction = actionCodes.SPEED_UP
            speedLevel += 1
        end

        while (currAction == lastAction) do
            if (playdate.isCrankDocked()) then
                currAction = math.random(1, actionCodes.CRANK_UNDOCK)
            else
                repeat
                    currAction = math.random(1, actionCodes.EOL - 1)
                until (currAction ~= actionCodes.CRANK_UNDOCK)
            end
            -- Disable MICROPHONE action on simulator without microphone access
            if (playdate.isSimulator and currAction == actionCodes.MICROPHONE) then
                currAction = lastAction
            end
        end

        -- increase deadzone after CRANKED action, so turning the crank
        -- a bit too far does not immediately fail the player
        if (lastAction == actionCodes.CRANKED) then
            crankDeadzone = CRANK_DEADZONE_AFTER_CRANKED
        else
            crankDeadzone = CRANK_DEADZONE_NORMAL
        end

        if (currAction == actionCodes.MICROPHONE) then
            mic.startListening()
        else
            mic.stopListening()
        end

        if (currAction == actionCodes.TILT) then
            startVec = { vec3D_norm(playdate.readAccelerometer()) }
        end

        -- always reset crank value, because it is checked for succeed and fail
        crankValue = 0
        actionDone = false
        actionTimer.duration = actions[currAction].time[speedLevel]
        actionTimer:reset()
        actionTimer:start()
    end

    render()
end

-- CALLBACKS

function playdate.upButtonDown()
    if (currAction == actionCodes.UP) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.rightButtonDown()
    if (currAction == actionCodes.RIGHT) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.downButtonDown()
    if (currAction == actionCodes.DOWN) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.leftButtonDown()
    if (currAction == actionCodes.LEFT) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.AButtonDown()
    if (currAction == actionCodes.A or currAction == actionCodes.LOSE) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.BButtonDown()
    if (currAction == actionCodes.B) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.crankDocked()
    if (currAction == actionCodes.CRANK_DOCK) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.crankUndocked()
    if (currAction == actionCodes.CRANK_UNDOCK) then
        actionSuccess()
    else
        actionFail()
    end
end

function playdate.cranked(change, acceleratedChange)
    crankValue += math.abs(change)
    if (currAction == actionCodes.CRANKED and crankValue >= CRANK_TARGET) then
        actionSuccess()
    elseif (currAction ~= actionCodes.CRANKED and crankValue >= crankDeadzone) then
        actionFail()
    end
end

function playdate.deviceWillLock()
    actionFail()
end

-- MAIN

setup()
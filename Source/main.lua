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


import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput
local v2d <const> = playdate.geometry.vector2D

local RAD_TO_DEG <const> = 180 / math.pi
local DEG_TO_RAD <const> = math.pi / 180

local playerSprite = nil
local font = gfx.font.new('images/font/whiteglove-stroked')
assert(font)

local actionCodes <const> = {
    UP = 1,
    RIGHT = 2,
    DOWN = 3,
    LEFT = 4,
    A = 5,
    B = 6,
    MICROPHONE = 7,
    TILT = 8,
    CRANK_UNDOCK = 9,
    CRANK_DOCK = 10,
    CRANKED = 11,
    EOL = 12,
}

local actions <const> = {
    [actionCodes.UP] = "Press UP",
    [actionCodes.RIGHT] = "Press RIGHT",
    [actionCodes.DOWN] = "Press DOWN",
    [actionCodes.LEFT] = "Press LEFT",
    [actionCodes.A] = "Press A",
    [actionCodes.B] = "Press B",
    [actionCodes.MICROPHONE] = "Blow in the microphone",
    [actionCodes.TILT] = "Tilt it",
    [actionCodes.CRANK_UNDOCK] = "Undock the Crank",
    [actionCodes.CRANK_DOCK] = "Dock the Crank",
    [actionCodes.CRANKED] = "Crank it!",
}

local CRANK_TARGET <const> = 3*360
local TILT_TARGET <const> = math.cos(50 * DEG_TO_RAD)
local TILT_TARGET_BACK <const> = math.cos(5 * DEG_TO_RAD)

local currAction = actionCodes.A
local actionDone = (currAction == nil)
local score = 0

local crankValue = 0
local startVec = nil
local tiltBack = false

-- CALLBACKS

function playdate.upButtonDown()
    if (currAction == actionCodes.UP) then
        actionSuccess()
    end
end

function playdate.rightButtonDown()
    if (currAction == actionCodes.RIGHT) then
        actionSuccess()
    end
end

function playdate.downButtonDown()
    if (currAction == actionCodes.DOWN) then
        actionSuccess()
    end
end

function playdate.leftButtonDown()
    if (currAction == actionCodes.LEFT) then
        actionSuccess()
    end
end

function playdate.AButtonDown()
    if (currAction == actionCodes.A) then
        actionSuccess()
    end
end

function playdate.BButtonDown()
    if (currAction == actionCodes.B) then
        actionSuccess()
    end
end

function playdate.crankDocked()
    if (currAction == actionCodes.CRANK_DOCK) then
        actionSuccess()
    end
end

function playdate.crankUndocked()
    if (currAction == actionCodes.CRANK_UNDOCK) then
        actionSuccess()
    end
end

function playdate.cranked(change, acceleratedChange)
    if (currAction == actionCodes.CRANKED) then
        crankValue += change
        if (crankValue >= CRANK_TARGET) then
            crankValue = 0
            actionSuccess()
        end
    end
end

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

function actionSuccess()
    actionDone = true
    score += 1
end

function actionFail()
    --
end

function myGameSetUp()
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

    if (actionDone) then
        local lastAction = currAction
        repeat
            if (playdate.isCrankDocked()) then
                currAction = math.random(1, actionCodes.CRANK_UNDOCK)
            else
                repeat
                    currAction = math.random(1, actionCodes.EOL - 1)
                until (currAction ~= actionCodes.CRANK_UNDOCK)
            end
        until (currAction ~= lastAction)

        if (currAction == actionCodes.MICROPHONE) then
            mic.startListening()
        else
            mic.stopListening()
        end

        if (currAction == actionCodes.TILT) then
            startVec = { vec3D_norm(playdate.readAccelerometer()) }
        end

        actionDone = false
    end

    gfx.sprite.update()
    playdate.timer.updateTimers()

	gfx.setFont(font)
	gfx.drawText('score: '..score, 2, 2)
    if (currAction == actionCodes.MICROPHONE) then
        gfx.drawText(string.format("level: %.0f", mic.getLevel() * 100), 2, 17)
    elseif (currAction == actionCodes.TILT) then
        gfx.drawText(string.format("a3d: %.2f", math.acos(vec3D_dot(startVec, playdate.readAccelerometer())) * RAD_TO_DEG), 2, 17)
        gfx.drawText(string.format("cos: %.4f", vec3D_dot(startVec, playdate.readAccelerometer())), 2, 32)
        gfx.drawText(string.format("target: %.4f", tiltBack and TILT_TARGET_BACK or TILT_TARGET), 2, 47)
    end
	gfx.drawText(actions[currAction], 200, 120)
end


myGameSetUp()
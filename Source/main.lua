-- Name this file `main.lua`. Your game can use multiple source files if you wish
-- (use the `import "myFilename"` command), but the simplest games can be written
-- with just `main.lua`.

-- You'll want to import these in just about every project you'll work on.

import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

-- Declaring this "gfx" shorthand will make your life easier. Instead of having
-- to preface all graphics calls with "playdate.graphics", just use "gfx."
-- Performance will be slightly enhanced, too.
-- NOTE: Because it's local, you'll have to do it in every .lua source file.

local gfx <const> = playdate.graphics
local mic <const> = playdate.sound.micinput

-- Here's our player sprite declaration. We'll scope it to this file because
-- several functions need to access it.

local playerSprite = nil
local font = gfx.font.new('images/font/whiteglove-stroked')
assert(font)

-- A function to set up our game environment.

local actionCodes <const> = {
    UP = 0,
    RIGHT = 1,
    DOWN = 2,
    LEFT = 3,
    A = 4,
    B = 5,
    MICROPHONE = 6,
    TILT = 7,
    CRANK_UNDOCK = 8,
    CRANK_DOCK = 9,
    CRANKED = 10,
    EOL = 11,
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

local currAction = nil
local actionDone = true
local score = 0
local crankValue = 0

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
            actionSuccess()
        end
    end
end

function actionSuccess()
    actionDone = true
    score += 1
end

function actionFail()

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
end



myGameSetUp()

function playdate.update()
    if (currAction == actionCodes.MICROPHONE and mic.getLevel() > 0.8) then
        actionSuccess()
    end

    if (currAction == actionCodes.TILT) then
        actionSuccess()
    end

    if (actionDone) then
        local lastAction = currAction
        repeat
            if (playdate.isCrankDocked()) then
                currAction = math.random(0, actionCodes.CRANK_UNDOCK)
            else
                repeat
                    currAction = math.random(0, actionCodes.EOL - 1)
                until (currAction ~= actionCodes.CRANK_UNDOCK)
            end
        until (currAction ~= lastAction)

        if (currAction == actionCodes.MICROPHONE) then
            mic.startListening()
        else
            mic.stopListening()
        end

        actionDone = false
    end

    gfx.sprite.update()
    playdate.timer.updateTimers()

	gfx.setFont(font)
	gfx.drawText('score: '..score, 2, 2)
	gfx.drawText(actions[currAction], 200, 120)
end


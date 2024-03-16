if transition then return end  -- avoid loading twice the same module
transition = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/timer"


local gfx <const> = playdate.graphics
local timer <const> = playdate.timer
local poly <const> = playdate.geometry.polygon

local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

local screenTransitionTimer
local transitionPolygon
local transitionTargetRender


-- 1--------------2
-- |              |
-- |              3
-- |             /
-- 5------------4

local function update_first_transition()
    timer.updateTimers()
    local dist = (SCREEN_HEIGHT + SCREEN_WIDTH) * screenTransitionTimer.currentTime / screenTransitionTimer.duration
    transitionPolygon:setPointAt(2, dist > SCREEN_WIDTH and SCREEN_WIDTH or dist, 0)
    transitionPolygon:setPointAt(3, dist > SCREEN_WIDTH and SCREEN_WIDTH or dist, dist > SCREEN_WIDTH and (dist - SCREEN_WIDTH) or 0)
    transitionPolygon:setPointAt(4, dist > SCREEN_HEIGHT and (dist - SCREEN_HEIGHT) or 0, dist > SCREEN_HEIGHT and SCREEN_HEIGHT or dist)
    transitionPolygon:setPointAt(5, 0, dist > SCREEN_HEIGHT and SCREEN_HEIGHT or dist)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(transitionPolygon)
end

--   4------------5
--  /             |
-- 3              |
-- |              |
-- 2--------------1

local function update_second_transition()
    timer.updateTimers()
    transitionTargetRender()
    local dist = (SCREEN_HEIGHT + SCREEN_WIDTH) * screenTransitionTimer.currentTime / screenTransitionTimer.duration
    transitionPolygon:setPointAt(2, dist > SCREEN_HEIGHT and (dist - SCREEN_HEIGHT) or 0, SCREEN_HEIGHT)
    transitionPolygon:setPointAt(3, dist > SCREEN_HEIGHT and (dist - SCREEN_HEIGHT) or 0, dist > SCREEN_HEIGHT and SCREEN_HEIGHT or dist)
    transitionPolygon:setPointAt(4, dist > SCREEN_WIDTH and SCREEN_WIDTH or dist, dist > SCREEN_WIDTH and (dist - SCREEN_WIDTH) or 0)
    transitionPolygon:setPointAt(5, SCREEN_WIDTH, dist > SCREEN_WIDTH and (dist - SCREEN_WIDTH) or 0)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillPolygon(transitionPolygon)
end

function transition.setup_second(targetSetupFunc, targetRenderFunc)
    screenTransitionTimer = timer.new(400, targetSetupFunc)
    transitionPolygon = poly.new(
        SCREEN_WIDTH, SCREEN_HEIGHT,
        0, SCREEN_HEIGHT,
        0, 0,
        0, 0,
        SCREEN_WIDTH, 0,
        SCREEN_WIDTH, SCREEN_HEIGHT
    )
    Statemachine.update = update_second_transition
    transitionTargetRender = targetRenderFunc
end

function transition.setup(targetSetupFunc, targetRenderFunc)
    screenTransitionTimer = timer.new(400, transition.setup_second, targetSetupFunc, targetRenderFunc)
    transitionPolygon = poly.new(0,0,0,0,0,0,0,0,0,0,0,0)
    Statemachine.update = update_first_transition
    transitionTargetRender = targetRenderFunc
end
if crankit then return end  -- avoid loading twice the same module
crankit = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "game_actions"
import "particles"

local gfx <const> = playdate.graphics
local mp3 <const> = playdate.sound.fileplayer
local mic <const> = playdate.sound.micinput
local ACTION_CODES <const> = actions.codes

local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

local SPEED_UP_INTERVAL <const> = 10
local MAX_SPEED_LEVEL <const> = 5
local TRANSITION_TIME_MS <const> = 500

local HIGHSCORE_STARS <const> = 40
local HIGHSCORE_BIG_ANI <const> = 55

local bgMusic <const> = {
    mp3.new("music/bg1"),
    mp3.new("music/bg2"),
    mp3.new("music/bg3"),
    mp3.new("music/bg4"),
    mp3.new("music/bg5")
}
local loseMusic <const> = mp3.new("music/lose")
local bigHighMusic <const> = mp3.new("music/stringed-disco")
local soundSuccess = playdate.sound.sampleplayer.new("sounds/success")
local bgSprite = nil


local actionDone = false
local actionTransitionState = -1 -- -1 not started, 0 running, 1 done
local actionTimer
local actionTransitionTimer
local speedLevel = 1
local score = 0
local newHighscore = false
local hideFirstHighscore = false
local lastAnimationFrame = 1
local actionCountSincePass = 0
local failReasonText = ""
local drawFailReason = false

local update_main


local failStarTimer
local failStarPos <const> = {
    { px = -17, py = 200, vx = 22, vy = -10 },
    { px = -17, py = 150, vx = 18, vy = -10 },
    { px = -17, py = 100, vx = 14, vy = -10 },
    { px = -17, py = 50, vx = 10, vy = -10 },
    { px = SCREEN_WIDTH + 17, py = 200, vx = -22, vy = -10 },
    { px = SCREEN_WIDTH + 17, py = 150, vx = -18, vy = -10 },
    { px = SCREEN_WIDTH + 17, py = 100, vx = -14, vy = -10 },
    { px = SCREEN_WIDTH + 17, py = 50, vx = -10, vy = -10 },
    { px = 80, py = SCREEN_HEIGHT + 17, vx = 15, vy = -20 },
    { px = 160, py = SCREEN_HEIGHT + 17, vx = 20, vy = -15 },
    { px = 240, py = SCREEN_HEIGHT + 17, vx = -15, vy = -20 },
    { px = 320, py = SCREEN_HEIGHT + 17, vx = -20, vy = -15 },
}

local function spawnFailStar()
    for i = 1, #failStarPos do
        if math.random(5) ~= 1 then goto continue end
        particles.add(
            "images/star",
            failStarPos[i].px,
            failStarPos[i].py,
            failStarPos[i].vx,
            failStarPos[i].vy,
            math.random(failStarPos[i].vx < 0 and failStarPos[i].vx or 0, failStarPos[i].vx > 0 and failStarPos[i].vx or 0)
        )
        ::continue::
    end
    failStarTimer:reset()
    failStarTimer:start()
end

local function update_highscore()
    if (actions.data[actions.current].ani ~= nil and lastAnimationFrame ~= actions.data[actions.current].img.frame) then
        lastAnimationFrame = actions.data[actions.current].img.frame
        gfx.sprite.redrawBackground()
    end
    playdate.timer.updateTimers()
    particles.update()
    gfx.sprite.update()
    if drawFailReason then
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(105, 18, 282, 135)
        gfx.drawTextAligned(failReasonText, 240, 40, kTextAlignment.center)
    end
    gfx.drawTextAligned('SCORE: '..score, 200, 220, kTextAlignment.center)
end

local function update_fail()
    playdate.timer.updateTimers()
end

local function main_startGame(skipGenNewAction)
    score = 0
    newHighscore = false
    hideFirstHighscore = save.data.highscore[GAME_MODE.CRANKIT] == 0
    speedLevel = 1
    Statemachine.gameShouldFailAfterResume = false

    if not skipGenNewAction then
        actions.current = actions.getValidActionCode()
    end
    actionCountSincePass = 0
    actions.setupActionGameplay(0, actions.current)
    actions.setupActionGfxAndSound(actions.current)
    actionDone = false
    actionTransitionState = -1
    if not actionTransitionTimer.paused then actionTransitionTimer:pause() end
    actionTimer.duration = actions.data[actions.current].time[speedLevel]
    actionTimer:reset()
    actionTimer:start()

    Statemachine.playMP3(bgMusic[1])
end

local main_buttonsLose = {
    AButtonDown = function()
        failStarTimer:pause()
        playdate.inputHandlers.pop()
        playdate.update = update_main
        main_startGame()
    end,
    BButtonDown = function()
        if actions.current == ACTION_CODES.LOSE then
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(135, 26, 220, 90)
            gfx.drawTextAligned(failReasonText, 240, 30, kTextAlignment.center)
        else
            drawFailReason = true
        end
    end,
}

local function main_actionSuccess()
    if actionDone then return end

    actionDone = true
    score = score + 1
    soundSuccess:play(1)
    actionCountSincePass = actionCountSincePass + 1

    particles.add("images/plusone", 110, 220, math.random(-10, 10) / 10, math.random(-110, -85) / 10, math.random(-10, 10))
    particles.add("images/plusone", 110, 220, math.random(-65, -45) / 10, math.random(-80, -60) / 10, math.random(-30, -5))
    particles.add("images/plusone", 110, 220, math.random(45, 65) / 10, math.random(-80, -60) / 10, math.random(5, 30))

    if score > save.data.highscore[GAME_MODE.CRANKIT] then
        save.data.highscore[GAME_MODE.CRANKIT] = score
        newHighscore = true
        if not hideFirstHighscore then
            particles.add("images/star", 290, 220, math.random(-10, 10) / 10, math.random(-110, -85) / 10, math.random(-10, 10))
            particles.add("images/star", 290, 220, math.random(-65, -45) / 10, math.random(-80, -60) / 10, math.random(-30, -5))
            particles.add("images/star", 290, 220, math.random(45, 65) / 10, math.random(-80, -60) / 10, math.random(5, 30))
        end
    end
end

local function main_actionFail(failReason)
    if actions.current < 1 then return end

    particles.clear()
    
    if newHighscore then
        save.write()
        if score >= HIGHSCORE_BIG_ANI then
            actions.current = ACTION_CODES.BIG_HIGHSCORE
            Statemachine.playMP3(bigHighMusic)
            failStarTimer:start()
        elseif score >= HIGHSCORE_STARS then
            actions.current = ACTION_CODES.STAR_HIGHSCORE
            Statemachine.music:stop()
            failStarTimer:start()
        else
            actions.current = ACTION_CODES.HIGHSCORE
            Statemachine.music:stop()
        end
        actions.setupActionGfxAndSound(actions.current)
        playdate.update = update_highscore
    else
        actions.current = ACTION_CODES.LOSE
        actions.setupActionGfxAndSound(actions.current)
        playdate.update = update_fail
        gfx.sprite.update()
        gfx.drawTextAligned('SCORE: '..score, 110, 220, kTextAlignment.center)
        gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)
        Statemachine.playMP3(loseMusic)
    end

    if failReason ~= nil then
        failReasonText = failReason
    else
        failReasonText = "BUTTERFLIES,\nQUANTUM EFFECTS,\nOR SOMETHING"
    end
    drawFailReason = false

    if not actionTimer.paused then actionTimer:pause() end
    playdate.inputHandlers.push(main_buttonsLose)
    mic.stopListening()
end

local function actionTimerEnd()
    if (actions.current == ACTION_CODES.PASS_PLAYER) then
        actionDone = true
        return
    elseif (actions.current == ACTION_CODES.SPEED_UP) then
        actionDone = true
        return
    end

    main_actionFail("YOU WERE\nNOT FAST\nENOUGH")
end

local function actionTransitionEnd()
    actionTransitionState = 1
end

local function render_main()
    if (actions.data[actions.current].ani ~= nil and lastAnimationFrame ~= actions.data[actions.current].img.frame) then
        lastAnimationFrame = actions.data[actions.current].img.frame
        gfx.sprite.redrawBackground()
    end

    particles.update()
    gfx.sprite.update()

    gfx.setColor(gfx.kColorBlack)
    if (not actionDone) then
        gfx.fillRect(0, SCREEN_HEIGHT - 22, SCREEN_WIDTH * actionTimer.timeLeft / actionTimer.duration, 22)
    elseif (actionTransitionState >= 0) then
        local w = SCREEN_WIDTH * actionTimer.timeLeft / actionTimer.duration
        w = w + (SCREEN_WIDTH - w) * (1 - actionTransitionTimer.timeLeft / actionTransitionTimer.duration)
        gfx.fillRect(0, SCREEN_HEIGHT - 22, w, 22)
    end

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)

    gfx.drawTextAligned('SCORE: '..score, 110, 220, kTextAlignment.center)
    if not hideFirstHighscore then
        gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)
    end

    if (save.data.settings.debugOn) then
        gfx.setFont(gfx.getSystemFont())
        local yPos = actions.renderDebugInfo()
        gfx.drawText(string.format("timer: %d", actionTimer.timeLeft), 2, yPos)
        yPos = yPos + 15
        if save.data.settings.allowPass then
            local passChance = actionCountSincePass * 100 / (ACTION_CODES._EOL + actionCountSincePass)
            gfx.drawText(string.format("pass chance: %.0f%%", passChance), 2, yPos)
            yPos = yPos + 15
        end
        gfx.setFont(Statemachine.font)
    end

    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

update_main = function ()
    if (Statemachine.gameShouldFailAfterResume) then
        main_actionFail("DON'T CHEAT\nBY OPENING\nTHE MENU")
        Statemachine.gameShouldFailAfterResume = false
        return
    end

    playdate.timer.updateTimers()

    local micResult = actions.checkMic()
    if (micResult == 1) then
        main_actionSuccess()
    elseif (micResult == -1) then
        main_actionFail("YOU WERE\nNOT QUIET\nENOUGH")
    end

    local tiltResult = actions.checkTilt()
    if (tiltResult == 1) then
        main_actionSuccess()
    elseif (tiltResult == -1) then
        main_actionFail("YOU SHOOK\nTHE PLAYDATE\nTOO MUCH")
    end

    -- other actions are handled in callbacks

    if (actionDone and actionTransitionState == -1) then
        actionTransitionTimer:reset()
        actionTransitionTimer:start()
        actionTimer:pause()
        actionTransitionState = 0
    elseif (actionDone and actionTransitionState == 1) then
        local lastAction = actions.current
        if (speedLevel < MAX_SPEED_LEVEL and score == SPEED_UP_INTERVAL * speedLevel) then
            actions.current = ACTION_CODES.SPEED_UP
            speedLevel = speedLevel + 1

            Statemachine.playMP3(bgMusic[speedLevel])
        else
            local passValue = math.random(ACTION_CODES._EOL + actionCountSincePass - 1)
            if save.data.settings.allowPass and lastAction ~= ACTION_CODES.PASS_PLAYER and passValue >= ACTION_CODES._EOL then
                actions.current = ACTION_CODES.PASS_PLAYER
                actionCountSincePass = 0
            else
                actions.current = actions.getValidActionCode(lastAction)
            end
        end

        actions.setupActionGameplay(lastAction, actions.current)
        actions.setupActionGfxAndSound(actions.current)
        lastAnimationFrame = 1

        actionDone = false
        actionTransitionState = -1
        actionTimer.duration = actions.data[actions.current].time[speedLevel]
        actionTimer:reset()
        actionTimer:start()
    end

    render_main()
end

local function cleanup_main()
    if bgSprite then bgSprite:remove() end
    playdate.stopAccelerometer()
    mic.stopListening()
    actionTimer:remove()
    actionTransitionTimer:remove()
    failStarTimer:remove()
    Statemachine.music:stop()
    particles.clear()
    -- pop twice to remove temp input handler from game over screen
    playdate.inputHandlers.pop()
    playdate.inputHandlers.pop()
end

function crankit.setup()
    bgSprite = gfx.sprite.setBackgroundDrawingCallback(
        function( x, y, width, height )
            -- x,y,width,height is the updated area in sprite-local coordinates
            -- The clip rect is already set to this area, so we don't need to set it ourselves
            actions.data[actions.current].img:draw(0,0)
        end
    )

    -- Accelerometer only returns values on next update cycle after startAccelerometer is called
    -- This is inconvenient for us, since we need to set startVec once tilt action comes up
    -- So we just enable the accelerometer during the whole game
    if save.data.settings.allowTilt then
        playdate.startAccelerometer()
    end
    playdate.inputHandlers.push(actions.buttonHandler)

    actionTimer = playdate.timer.new(100, actionTimerEnd) -- dummy duration, proper value set in main_startGame
    actionTimer.discardOnCompletion = false
    actionTransitionTimer = playdate.timer.new(TRANSITION_TIME_MS, actionTransitionEnd)
    actionTransitionTimer.discardOnCompletion = false
    actionTransitionTimer:pause()

    failStarTimer = playdate.timer.new(500, spawnFailStar)
    failStarTimer.discardOnCompletion = false
    failStarTimer:pause()

    playdate.update = update_main
    Statemachine.cleanup = cleanup_main
    actions.succesFnc = main_actionSuccess
    actions.failFnc = main_actionFail
    particles.setDefaultPhysics()

    -- NOTE: This assumes pre_setup_main_for_transition was called before
    main_startGame(true)
end

function crankit.render_for_transition()
    if actions.data[actions.current].ani ~= nil then
        actions.data[actions.current].img.frame = 1
    end
    actions.data[actions.current].img:draw(0,0)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, SCREEN_HEIGHT - 22, SCREEN_WIDTH, 22)

    gfx.setImageDrawMode(gfx.kDrawModeNXOR)
    gfx.drawTextAligned('SCORE: 0', 110, 220, kTextAlignment.center)
    if save.data.highscore[GAME_MODE.CRANKIT] > 0 then
        gfx.drawTextAligned("HIGH: "..save.data.highscore[GAME_MODE.CRANKIT], 290, 220, kTextAlignment.center)
    end
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
end

function crankit.pre_setup_for_transition()
    actions.current = actions.getValidActionCode()
end
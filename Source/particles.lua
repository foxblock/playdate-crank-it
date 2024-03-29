if particles then return end  -- avoid loading twice the same module
particles = {}  -- create a table to represent the module

import "CoreLibs/graphics"
import "CoreLibs/sprites"

local gfx <const> = playdate.graphics
local SCREEN_WIDTH <const> = playdate.display.getWidth()
local SCREEN_HEIGHT <const> = playdate.display.getHeight()

local gravity <const> = 1
local friction <const> = 0.92
local entities = {}

function particles.add(imgPath, x, y, velx, vely, velrot)
    local p = {
        img = gfx.sprite.new(gfx.image.new(imgPath)),
        vx = velx,
        vy = vely,
        rot = velrot
    }
    p.hw, p.hh = p.img:getSize()
    p.hw, p.hh = p.hw / 2, p.hh / 2
    
    p.img:add()
    p.img:moveTo(x, y)

    table.insert(entities, p)
end

function particles.update()
    for k, p in pairs(entities) do
        p.img:moveBy(p.vx, p.vy)

        if p.img.x < -p.hw 
            or p.img.x > SCREEN_WIDTH + p.hw 
            or p.img.y < -p.hh 
            or p.img.y > SCREEN_HEIGHT + p.hh 
        then
            p.img:remove()
            particles[k] = nil
        end

        p.vx = p.vx * friction
        p.vy = p.vy + gravity
        if p.rot ~= 0 then
            p.img:setRotation(p.img:getRotation() + p.rot)
        end
    end
end
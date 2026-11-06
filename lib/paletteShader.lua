-- Mostly taken from https://love2d.org/forums/viewtopic.php?p=211460&sid=0837416402b7c478107097dd083f7f90#p211460 - thanks!
local paletteShader = {}

local sh_swap_colors = love.filesystem.read("lib/paletteShader.glsl")

local shader = love.graphics.newShader(sh_swap_colors)
shader:send("n", 0)

function paletteShader.on(imgPalette, newPalette)
    if imgPalette then
        local count = math.min(#imgPalette, 4, #newPalette)
        shader:send("n", count)
        shader:sendColor("oldColors", unpack(imgPalette, 1, count))
        shader:sendColor("newColors", unpack(newPalette, 1, count))
    end

    love.graphics.setShader(shader)
end

function paletteShader.off()
    love.graphics.setShader()
end

return paletteShader
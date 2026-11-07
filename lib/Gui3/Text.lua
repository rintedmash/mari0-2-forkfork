local Gui3 = ...
Gui3.Text = class("Gui3.Text", Gui3.Element)

Gui3.Text.noMouseEvents = true

function Gui3.Text:initialize(s, x, y, wrapWidth)
    self.s = s
    self.wrapWidth = wrapWidth
    self.text = love.graphics.newText(fontOutlined, self:wrapped(s))

    -- Size from the Text object: Font:getHeight ignores the string, so a
    -- wrapped multi-line string would be measured as a single line
    Gui3.Element.initialize(self, x, y, self.text:getWidth(), self.text:getHeight())
end

-- Word-wrap the string to self.wrapWidth screen pixels (nil = no wrap)
function Gui3.Text:wrapped(s)
    if not self.wrapWidth then
        return s
    end

    local lines = {}
    for paragraph in tostring(s or ""):gmatch("[^\n]*") do
        local line = ""

        for word in paragraph:gmatch("%S+") do
            local candidate = line == "" and word or (line .. " " .. word)

            if line ~= "" and fontOutlined:getWidth(candidate) > self.wrapWidth then
                table.insert(lines, line)
                line = word
            else
                line = candidate
            end
        end

        table.insert(lines, line)
    end

    return table.concat(lines, "\n")
end

function Gui3.Text:setString(s)
    if self.s ~= s then
        self.s = s
        self.text:set(self:wrapped(s))

        self:updateRender()

        if self.w ~= self.text:getWidth() or self.h ~= self.text:getHeight() then
            self.w = self.text:getWidth()
            self.h = self.text:getHeight()
            self:sizeChanged()
        end
    end
end

function Gui3.Text:draw()
    Gui3.Element.draw(self)

    love.graphics.draw(self.text, 0, -1)
end

return Gui3.Text

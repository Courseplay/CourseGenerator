dofile('include.lua')

local dragging = false
local pointSize = 1
local lineWidth = 0.1
local scale = 1.0
local xOffset, yOffset = 10000, 10000
local windowWidth = 1400
local windowHeight = 800
local showWidth = false
local currentWaypointIndex = 1
local offset = 0

---@type cg.Field
local field
local savedFields

function love.load(arg)
    local fileName = arg[1]
    cg.debug('Reading %s...', fileName)
    savedFields = cg.Field.loadSavedFields(fileName)
    print("Fields found in file:")
    for _, f in pairs(savedFields) do
        if f:getId() == tonumber(arg[2]) then
            field = f
        end
    end
    local x1, y1, x2, y2 = field:getBoundingBox()
    local fieldWidth, fieldHeight = x2 - x1, y2 - y1
    local xScale = windowWidth / fieldWidth
    local yScale = windowHeight / fieldHeight
    if xScale > yScale then
        scale = 0.9 * yScale
        pointSize = 0.9 * yScale
    else
        scale = 0.9 * xScale
        pointSize = 0.9 * xScale
    end

    local fieldCenter = field:getCenter()
    -- translate into the middle of the window and remember, the window size is not scaled so must
    -- divide by scale
    xOffset = -(fieldCenter.x - windowWidth / 2 / scale)
    -- need to offset with window height as we flip the y axle so the origin is in the bottom left corner
    -- of the window
    yOffset = -(fieldCenter.y - windowHeight / 2 / scale) - windowHeight / scale
    love.graphics.setPointSize(pointSize)
    love.graphics.setLineWidth(lineWidth)
    love.window.setMode(windowWidth, windowHeight)
    love.window.setTitle(string.format('Course Generator - %s - Field %d', fileName, field:getId()))
end

local function love2real(x, y)
    return (x / scale) - xOffset, -(y / scale) - yOffset
end

local function drawPolygon(polygon)
    for i, point in ipairs(polygon) do
        love.graphics.points(point.x, point.y)
        love.graphics.push()
        love.graphics.scale(1, -1)
        love.graphics.print(i, point.x, -point.y, 0, 0.2)
        love.graphics.pop()
    end
end

local function drawField()
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(100, 100, 100)
    love.graphics.polygon('line', field:getUnpackedVertices())
end

function love.draw()
    love.graphics.scale(scale, -scale)
    love.graphics.translate(xOffset, yOffset)
    love.graphics.setPointSize(pointSize)
    drawField(field)
end

------------------------------------------------------------------------------------------------------------------------
--- Input
---------------------------------------------------------------------------------------------------------------------------
function love.textinput(key)


end

------------------------------------------------------------------------------------------------------------------------
--- Pan/Zoom
---------------------------------------------------------------------------------------------------------------------------
function love.wheelmoved(dx, dy)
    scale = scale + scale * dy * 0.03
    pointSize = pointSize + pointSize * dy * 0.04
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        dragging = true
    end
end

function love.mousereleased(x, y, button, istouch)
    if button == 1 then
        dragging = false
    end
end

function love.mousemoved(x, y, dx, dy)
    if dragging then
        xOffset = xOffset + dx / scale
        yOffset = yOffset - dy / scale
    end
end

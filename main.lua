--
-- Graphical test tool for the Fieldwork Course Generator
--
-- Usage:
--   love.exe . <selectedField definitions file> <selectedField number>
--
-- where 'selectedField definitions file' is an XML file that can be created from the
-- Farming Simulator game console command cpSaveAllFields. The file will contain
-- the boundaries of all owned fields of the current map, including selectedField islands.
--
--
dofile('include.lua')

local dragging = false
local pointSize = 1
local lineWidth = 0.1
local scale = 1.0
local windowWidth = 1400
local windowHeight = 800

local graphicsTransform, statusTransform, mouseTransform, contextTransform

local fieldBoundaryColor = { 0.5, 0.5, 0.5 }
local courseColor = { 0, 0.7, 1 }
local islandHeadlandColor = { 0, 0.7, 1 }
local waypointColor = { 0.7, 0.5, 0.2 }

local parameters = {}
-- number of headland passes around the field boundary
local nHeadlandPasses = AdjustableParameter(1, 'headlands', 'P', 'p', 1, 0, 100); table.insert(parameters, nHeadlandPasses)
local nHeadlandsWithRoundCorners = AdjustableParameter(0, 'headlands with round corners', 'C', 'c', 1, 0, 100); table.insert(parameters, nHeadlandsWithRoundCorners)
-- number of headland passes around the field islands
local nIslandHeadlandPasses = AdjustableParameter(1, 'island headlands', 'I', 'i', 1, 1, 10); table.insert(parameters, nIslandHeadlandPasses)
-- working width of the equipment
local workingWidth = AdjustableParameter(8, 'width', 'W', 'w', 0.2, 0, 100); table.insert(parameters, workingWidth)
local turningRadius = AdjustableParameter(6, 'radius', 'T', 't', 0.2, 0, 20); table.insert(parameters, turningRadius)
local fieldCornerRadius = AdjustableParameter(6, 'field corner radius', 'F', 'f', 1, 0, 30); table.insert(parameters, fieldCornerRadius)
local maxEdgeLength = ToggleParameter('limit edge length', false, 'e'); table.insert(parameters, maxEdgeLength)

-- the selectedField to generate the course for
---@type cg.Field
local selectedField
-- the generated fieldwork course
---@type cg.FieldworkCourse
local course
local savedFields
local currentVertex

------------------------------------------------------------------------------------------------------------------------
--- Generate the fieldwork course
---------------------------------------------------------------------------------------------------------------------------
local function generate()
    local context = cg.FieldworkContext(selectedField, workingWidth:get(), turningRadius:get(), nHeadlandPasses:get())
    context:setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners:get())
    context:setIslandHeadlands(nIslandHeadlandPasses:get())
    context:setFieldCornerRadius(fieldCornerRadius:get())
    course = cg.FieldworkCourse(context)
    course:generateHeadlands()
    course:generateHeadlandsAroundIslands()
    -- make sure all logs are now visible
    io.stdout:flush()
end

function love.load(arg)
    local fileName = arg[1]
    cg.debug('Reading %s...', fileName)
    savedFields = cg.Field.loadSavedFields(fileName)
    print("Fields found in file:")
    for _, f in pairs(savedFields) do
        if f:getId() == tonumber(arg[2]) then
            selectedField = f
        end
    end
    local x1, y1, x2, y2 = selectedField:getBoundingBox()
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
    local fieldCenter = selectedField:getCenter()
    graphicsTransform = love.math.newTransform(0, 0, 0, scale, -scale, fieldCenter.x - fieldWidth / 2, fieldCenter.y + fieldHeight / 2, 0, 0)    -- translate into the middle of the window and remember, the window size is not scaled so must
    statusTransform = love.math.newTransform(0, 0, 0, 1, 1, -windowWidth + 200, -windowHeight + 30)
    mouseTransform = love.math.newTransform()
    contextTransform = love.math.newTransform(10, 10, 0, 1, 1, 0, 0)
    love.graphics.setPointSize(pointSize)
    love.graphics.setLineWidth(lineWidth)
    love.window.setMode(windowWidth, windowHeight)
    love.window.setTitle(string.format('Course Generator - %s - SelectedField %d', fileName, selectedField:getId()))
    generate()
end

local function screenToWorld(sx, sy)
    return graphicsTransform:inverseTransformPoint(sx, sy)
end

local function floatToString(f)
    if f then
        return string.format('%.1f', f)
    else
        return 'nil'
    end
end

local function intToString(d)
    if d then
        return string.format('%d', d)
    else
        return 'nil'
    end
end

local function findVertexForPosition(polygon, rx, ry)
    for _, v in polygon:vertices() do
        if math.abs(v.x - rx) < 0.3 and math.abs(v.y - ry) < 0.3 then
            return v
        end
    end
    return nil
end

local function findCurrentVertex(sx, sy)
    local x, y = screenToWorld(sx, sy)
    for _, h in ipairs(course:getHeadlands()) do
        local v = findVertexForPosition(h:getPolygon(), x, y)
        if v then
            return v
        end
    end
end

local function selectFieldUnderCursor()
    local x, y = love.mouse.getPosition()
    x, y = screenToWorld(x, y)
    for _, f in pairs(savedFields) do
        if f:getBoundary():isInside(x, y) then
            print(string.format('Field %d selected', f:getId()))
            selectedField = f
            generate()
        end
    end
end

local function drawHeadland(h, color)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.setColor(color)
    love.graphics.polygon('line', h:getUnpackedVertices())
    for _, v in h:getPolygon():vertices() do
        if v.color then
            love.graphics.setColor(v.color)
        else
            love.graphics.setColor(waypointColor)
        end
        love.graphics.points(v.x, v.y)
    end
end

local function drawFields()
    love.graphics.setLineWidth(lineWidth)
    for _, f in pairs(savedFields) do
        love.graphics.setColor(fieldBoundaryColor)
        love.graphics.polygon('line', f:getUnpackedVertices())
        for _, i in ipairs(f:getIslands()) do
            love.graphics.setColor(fieldBoundaryColor)
            love.graphics.polygon('fill', i:getBoundary():getUnpackedVertices())
            for _, h in ipairs(i:getHeadlands()) do
                drawHeadland(h, islandHeadlandColor)
            end
        end
    end
end

local function drawHeadlands()
    for _, h in ipairs(course:getHeadlands()) do
        drawHeadland(h, courseColor)
    end
end

-- Draw a tooltip with the vertex' details
local function drawVertexInfo()
    love.graphics.replaceTransform(mouseTransform)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', 0, 0, 100, 150)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf(string.format('ix: %s r: %s',
            intToString(currentVertex.ix), floatToString(currentVertex:getRadius())), 10, 10, 130)
    love.graphics.printf(string.format('c: %.1f xte: %.2f', currentVertex.curvature, currentVertex.xte), 10, 24, 130)
end

local function drawGraphics()
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setPointSize(pointSize)
    drawFields()
    drawHeadlands()
end

local function drawContext()
    love.graphics.setColor(1, 1, 0)
    love.graphics.replaceTransform(contextTransform)
    local context = ''
    for _, p in ipairs(parameters) do
        context = context .. tostring(p) .. '\n'
    end
    love.graphics.print(context, 0, 0)
end

local function drawStatus()
    love.graphics.setColor(1, 1, 0)
    love.graphics.replaceTransform(statusTransform)
    local mx, my = love.mouse.getPosition()
    local x, y = screenToWorld(mx, my)
    love.graphics.print(string.format('%.1f %.1f', x, y), 0, 0)
    if currentVertex then
        drawVertexInfo()
    end
end

function love.draw()
    drawGraphics()
    drawStatus()
    drawContext()
end

------------------------------------------------------------------------------------------------------------------------
--- Input
---------------------------------------------------------------------------------------------------------------------------
function love.textinput(key)
    for _, p in pairs(parameters) do
        p:onKey(key, generate)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Pan/Zoom
---------------------------------------------------------------------------------------------------------------------------
function love.wheelmoved(dx, dy)
    graphicsTransform = graphicsTransform:scale(1 + dy * 0.03)
    pointSize = pointSize + pointSize * dy * 0.02
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        dragging = true
    end
end

function love.mousereleased(x, y, button, istouch)
    if button == 1 then
        dragging = false
    elseif button == 2 then
        selectFieldUnderCursor()
    end
end

function love.mousemoved(x, y, dx, dy)
    if dragging then
        graphicsTransform:translate(0.5 * dx, -0.5 * dy)
    end
    mouseTransform:setTransformation(x + 20, y + 20)
    currentVertex = findCurrentVertex(x, y)
end

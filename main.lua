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
local profilerEnabled = false
local fileName = ''
local dragging = false
local pointSize = 1
local lineWidth = 0.1
local scale = 1.0
local windowWidth = 1400
local windowHeight = 800
local xOffset, yOffset = 0, 0
-- starting position
local startX, startY

local graphicsTransform, statusTransform, mouseTransform, contextTransform

local fieldBoundaryColor = { 0.5, 0.5, 0.5 }
local courseColor = { 0, 0.7, 1 }
local islandHeadlandColor = { 1, 1, 1, 0.2 }
local waypointColor = { 0.7, 0.5, 0.2 }
local cornerColor = { 1, 1, 0.0, 0.8 }
local islandBypassColor = { 0, 0.2, 1.0 }
local debugColor = { 0.8, 0, 0, 0.5 }
local highlightedWaypointColorForward = { 0, 0.7, 0, 0.3 }
local highlightedWaypointColorBackward = { 0.7, 0, 0, 0.3 }
local centerColor = { 0, 0.7, 1, 0.5 }
local islandPointColor = { 0.7, 0, 0.7, 0.4 }
local islandPerimeterPointColor = { 1, 0.4, 1 }

local parameters = {}
-- number of headland passes around the field boundary
local nHeadlandPasses = AdjustableParameter(4, 'headlands', 'P', 'p', 1, 0, 100);
table.insert(parameters, nHeadlandPasses)
local nHeadlandsWithRoundCorners = AdjustableParameter(0, 'headlands with round corners', 'R', 'r', 1, 0, 100);
table.insert(parameters, nHeadlandsWithRoundCorners)
local headlandClockwise = ToggleParameter('headlands clockwise', false, 'c');
table.insert(parameters, headlandClockwise)
-- number of headland passes around the field islands
local nIslandHeadlandPasses = AdjustableParameter(1, 'island headlands', 'I', 'i', 1, 1, 10);
table.insert(parameters, nIslandHeadlandPasses)
-- working width of the equipment
local workingWidth = AdjustableParameter(8.4, 'width', 'W', 'w', 0.2, 0, 100);
table.insert(parameters, workingWidth)
local turningRadius = AdjustableParameter(5.8, 'radius', 'T', 't', 0.2, 0, 20);
table.insert(parameters, turningRadius)
local fieldCornerRadius = AdjustableParameter(6, 'field corner radius', 'F', 'f', 1, 0, 30);
table.insert(parameters, fieldCornerRadius)
local sharpenCorners = ToggleParameter('sharpen corners', true, 's');
table.insert(parameters, sharpenCorners)
local bypassIslands = ToggleParameter('bypass islands', false, 'b');
table.insert(parameters, bypassIslands)
local autoRowAngle = ToggleParameter('auto row angle',false, '6');
table.insert(parameters, autoRowAngle)
local rowAngleDeg = AdjustableParameter(-90, 'row angle', 'A', 'a', 10, -90, 90);
table.insert(parameters, rowAngleDeg)
local evenRowDistribution = ToggleParameter('even row width', false, 'e');
table.insert(parameters, evenRowDistribution)

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
    cg.debugPoints = {}
    local context = cg.FieldworkContext(selectedField, workingWidth:get(), turningRadius:get(), nHeadlandPasses:get())
    context:setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners:get())
    context:setHeadlandClockwise(headlandClockwise:get())
    context:setIslandHeadlands(nIslandHeadlandPasses:get())
    context:setFieldCornerRadius(fieldCornerRadius:get())
    context:setBypassIslands(bypassIslands:get())
    context:setSharpenCorners(sharpenCorners:get())
    context:setAutoRowAngle(autoRowAngle:get())
    context:setRowAngle(math.rad(rowAngleDeg:get()))
    context:setEvenRowDistribution(evenRowDistribution:get())
    if startX then
        context:setStartLocation(startX, startY)
    end
    if profilerEnabled then
        love.profiler.start()
    end
    course = cg.FieldworkCourse(context)
    course:generateHeadlands()
    course:generateHeadlandsAroundIslands()
    course:generateUpDownRows()
    if profilerEnabled then
        print(love.profiler.report(40))
        love.profiler.reset()
        love.profiler.stop()
    end
    -- make sure all logs are now visible
    io.stdout:flush()
end

local function updateTransform()
    graphicsTransform = love.math.newTransform(xOffset, yOffset, 0, 1, 1, 0, 0, 0, 0):scale(scale, -scale)
end

--- Set offset so with the current scale, the world coordinates x, y are in the middle of the screen
local function setOffset(x, y)
    xOffset = -(scale * x - windowWidth / 2)
    yOffset = (scale * y - windowHeight / 2) + windowHeight
end

function love.load(arg)
    if profilerEnabled then
        love.profiler = require('profile')
    end
    fileName = arg[1]
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
    -- world offset
    --scale = 1
    setOffset(fieldCenter.x, fieldCenter.y)
    updateTransform()
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
    local v = findVertexForPosition(course:getHeadland(), x, y)
    if v then
        return v
    end
end

local function selectFieldUnderCursor()
    local x, y = love.mouse.getPosition()
    startX, startY = screenToWorld(x, y)
    for _, f in pairs(savedFields) do
        if f:getBoundary():isInside(startX, startY) then
            print(string.format('Field %d selected', f:getId()))
            selectedField = f
            love.window.setTitle(string.format('Course Generator - %s - SelectedField %d', fileName, selectedField:getId()))
            generate()
        end
    end
end

local function drawVertex(v)
    if v.color then
        love.graphics.setColor(v.color)
    else
        love.graphics.setColor(waypointColor)
    end
    if v.isCorner then
        love.graphics.setColor(cornerColor)
    end
    if v:getAttributes():getIslandBypass() then
        love.graphics.setColor(islandBypassColor)
    end
    love.graphics.points(v.x, v.y)
end

local function drawHeadland(h, color)
    if #h > 1 then
        love.graphics.setLineWidth(lineWidth)
        love.graphics.setColor(color)
        love.graphics.line(h:getUnpackedVertices())
        --love.graphics.polygon('line', h:getUnpackedVertices())
        for _, v in h:vertices() do
            drawVertex(v)
        end
    end
end

local function drawIslandHeadland(h, color)
    love.graphics.setLineWidth(10 * lineWidth)
    love.graphics.setColor(color)
    love.graphics.polygon('line', h:getUnpackedVertices())
end

local function drawCenter()
    if course:getCenter() then
        love.graphics.setLineWidth(lineWidth)
        love.graphics.setColor(centerColor)
        local c = course:getCenter()
        for i = 1, #c, 2 do
            love.graphics.line(c[i].x, c[i].y, c[i + 1].x, c[i + 1].y)
        end
    end
end


local function drawFields()
    for _, f in pairs(savedFields) do
        love.graphics.setLineWidth(lineWidth)
        love.graphics.setColor(fieldBoundaryColor)
        love.graphics.polygon('line', f:getUnpackedVertices())
        for _, v in ipairs(f:getBoundary()) do
            love.graphics.points(v.x, v.y)
        end
        for _, i in ipairs(f:getIslands()) do
            love.graphics.setColor(fieldBoundaryColor)
            if #i:getBoundary() > 2 then
                love.graphics.polygon('line', i:getBoundary():getUnpackedVertices())
            end
            for _, h in ipairs(i:getHeadlands()) do
               drawIslandHeadland(h, islandHeadlandColor)
            end
            for _, p in ipairs(f.islandPoints) do
                love.graphics.setColor(islandPointColor)
                love.graphics.points(p.x, p.y)
            end
            for _, p in ipairs(f.islandPerimeterPoints) do
                love.graphics.setColor(islandPerimeterPointColor)
                love.graphics.points(p.x, p.y)
            end
        end
        love.graphics.setColor(fieldBoundaryColor)
        local c = f:getCenter()
        love.graphics.push()
        love.graphics.scale(1, -1)
        love.graphics.print(f:getId(), c.x, -c.y)
        love.graphics.pop()
    end
end

local function drawHeadlands()
    --for _, h in ipairs(course:getHeadlands()) do
    drawHeadland(course:getHeadland(), courseColor)
    --end
end

-- Draw a tooltip with the vertex' details
local function drawVertexInfo(v)
    love.graphics.replaceTransform(mouseTransform)
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', 0, 0, 100, 150)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf(string.format('ix: %s old: %s',
            intToString(v.ix), intToString(v.oldIx)), 10, 12, 130)
    love.graphics.printf(string.format('r: %s xte: %s',
            floatToString(v:getSignedRadius()), floatToString(v.xte)), 10, 24, 130)
    love.graphics.printf(string.format('corner: %s', v.isCorner), 10, 36, 130)
    love.graphics.printf(string.format('x: %s y: %s',
            floatToString(v.x), floatToString(v.y)), 10, 48, 130)
end

-- Highlight a few vertices around the selected one
local function highlightPathAroundVertex(v)
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setPointSize(pointSize * 3)
    for i = v.ix - 20, v.ix + 30 do
        love.graphics.setColor(i < v.ix and highlightedWaypointColorBackward or highlightedWaypointColorForward)
        local p = course:getHeadland():at(i)
        if p then
            love.graphics.points(p.x, p.y)
        end
    end
end

local function drawGraphics()
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setPointSize(pointSize)
    drawFields()
    drawHeadlands()
    drawCenter()
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
    love.graphics.print(string.format('%.1f %.1f (%.1f %.1f / %.1f)', x, y, xOffset, yOffset, scale), 0, 0)
    if currentVertex then
        drawVertexInfo(currentVertex)
        highlightPathAroundVertex(currentVertex)
    end
end

local function drawDebugPoints()
    if cg.debugPoints then
        love.graphics.replaceTransform(graphicsTransform)
        love.graphics.setColor(debugColor)
        love.graphics.setPointSize(pointSize * 3)
        for _, p in ipairs(cg.debugPoints) do
            love.graphics.points(p.x, p.y)
        end
    end
end

function love.draw()
    drawGraphics()
    drawStatus()
    drawContext()
    drawDebugPoints()
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
    -- when zooming, keep the window center in place
    local windowCenterX, windowCenterY = screenToWorld(windowWidth / 2, windowHeight / 2)
    scale = scale * (1 + dy * 0.03)
    setOffset(windowCenterX, windowCenterY)
    updateTransform()
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
        xOffset = xOffset + dx
        yOffset = yOffset + dy
        updateTransform()
    end
    mouseTransform:setTransformation(x + 20, y + 20)
    currentVertex = findCurrentVertex(x, y)
end

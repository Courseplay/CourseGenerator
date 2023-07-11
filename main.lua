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

local parameters = {}
-- working width of the equipment
local workingWidth = AdjustableParameter(7.8, 'width', 'W', 'w', 0.2, 0, 100)
table.insert(parameters, workingWidth)
local turningRadius = AdjustableParameter(5.8, 'radius', 'T', 't', 0.2, 0, 20)
table.insert(parameters, turningRadius)
-- number of headland passes around the field boundary
local nHeadlandPasses = AdjustableParameter(2, 'headlands', 'P', 'p', 1, 0, 100)
table.insert(parameters, nHeadlandPasses)
local nHeadlandsWithRoundCorners = AdjustableParameter(0, 'headlands with round corners', 'R', 'r', 1, 0, 100)
table.insert(parameters, nHeadlandsWithRoundCorners)
local headlandClockwise = ToggleParameter('headlands clockwise', false, 'c')
table.insert(parameters, headlandClockwise)
local headlandFirst = ToggleParameter('headlands first', true, 'f')
table.insert(parameters, headlandFirst)
-- number of headland passes around the field islands
local nIslandHeadlandPasses = AdjustableParameter(1, 'island headlands', 'I', 'i', 1, 1, 10)
table.insert(parameters, nIslandHeadlandPasses)
local fieldCornerRadius = AdjustableParameter(6, 'field corner radius', 'F', 'f', 1, 0, 30)
table.insert(parameters, fieldCornerRadius)
local sharpenCorners = ToggleParameter('sharpen corners', true, 's')
table.insert(parameters, sharpenCorners)
local bypassIslands = ToggleParameter('bypass islands', true, 'b')
table.insert(parameters, bypassIslands)
local autoRowAngle = ToggleParameter('auto row angle', true, '6')
table.insert(parameters, autoRowAngle)
local rowAngleDeg = AdjustableParameter(-90, 'row angle', 'A', 'a', 10, -90, 90)
table.insert(parameters, rowAngleDeg)
local rowPattern = ListParameter(cg.RowPattern.LANDS, 'row pattern', 'O', 'o',
        { cg.RowPattern.ALTERNATING,
          cg.RowPattern.SKIP,
          cg.RowPattern.SPIRAL,
          cg.RowPattern.LANDS
        },
        {
            'alternating',
            'skip',
            'spiral',
            'lands'
        })
table.insert(parameters, rowPattern)
local nRows = AdjustableParameter(4, 'rows to skip/rows per land', 'K', 'k', 1, 0, 10)
table.insert(parameters, nRows)
local leaveSkippedRowsUnworked = ToggleParameter('leave skipped rows unworked', false, 'u')
table.insert(parameters, leaveSkippedRowsUnworked)
local centerClockwise = ToggleParameter('spiral/lands clockwise', true, '1')
table.insert(parameters, centerClockwise)
local spiralFromInside = ToggleParameter('spiral from inside', true, '!')
table.insert(parameters, spiralFromInside)
local evenRowDistribution = ToggleParameter('even row width', false, 'e')
table.insert(parameters, evenRowDistribution)
local useBaselineEdge = ToggleParameter('use base line edge', false, 'g')
table.insert(parameters, useBaselineEdge)
local showDebugInfo = ToggleParameter('show debug info', false, 'd', true)
table.insert(parameters, showDebugInfo)

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
local startX, startY, baselineX, baselineY = 0, 0, 0, 0

local graphicsTransform, textTransform, statusTransform, mouseTransform, contextTransform

local fieldBoundaryColor = { 0.5, 0.5, 0.5 }
local courseColor = { 0, 0.7, 1 }
local islandHeadlandColor = { 1, 1, 1, 0.2 }
local waypointColor = { 0.7, 0.5, 0.2 }
local cornerColor = { 1, 1, 0.0, 0.8 }
local islandBypassColor = { 0, 0.2, 1.0 }
local debugColor = { 0.8, 0, 0, 0.5 }
local highlightedWaypointColorForward = { 0, 0.7, 0, 0.3 }
local highlightedWaypointColorBackward = { 0.7, 0, 0, 0.3 }
local centerColor = { 0, 0.7, 1, 0.8 }
local centerFontColor = { 0, 0.7, 1 }
local blockColor = { 1, 0.5, 0, 0.2 }
local blockFontColor = { 1, 0.5, 0, 1 }
local rowEndColor = { 0, 1, 0, 1 }
local rowStartColor = { 1, 0, 0, 1 }
local connectingPathColor = { 0.3, 0.3, 0.3, 1 }
local connectingPathFontColor = { 0.8, 0.8, 0.8, 1 }
local swathColor = { 0, 0.7, 0, 0.25 }
local islandPointColor = { 0.7, 0, 0.7, 0.4 }
local islandPerimeterPointColor = { 1, 0.4, 1 }


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
    cg.clearDebugObjects()
    local context = cg.FieldworkContext(selectedField, workingWidth:get(), turningRadius:get(), nHeadlandPasses:get())
    context:setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners:get())
    context:setHeadlandClockwise(headlandClockwise:get())
    context:setHeadlandFirst(headlandFirst:get())
    context:setIslandHeadlands(nIslandHeadlandPasses:get())
    context:setFieldCornerRadius(fieldCornerRadius:get())
    context:setBypassIslands(bypassIslands:get())
    context:setSharpenCorners(sharpenCorners:get())
    context:setAutoRowAngle(autoRowAngle:get())
    context:setRowAngle(math.rad(rowAngleDeg:get()))
    context:setEvenRowDistribution(evenRowDistribution:get())
    context:setUseBaselineEdge(useBaselineEdge:get())
    context:setStartLocation(startX, startY)
    context:setBaselineEdge(startX, startY)
    context:setBaselineEdge(baselineX, baselineY)
    if profilerEnabled then
        love.profiler.start()
    end
    if rowPattern:get() == cg.RowPattern.SPIRAL then
        context:setRowPattern(cg.RowPattern.create(rowPattern:get(), centerClockwise:get(), spiralFromInside:get()))
    elseif rowPattern:get() == cg.RowPattern.LANDS then
        context:setRowPattern(cg.RowPattern.create(rowPattern:get(), centerClockwise:get(), nRows:get()))
    else
        context:setRowPattern(cg.RowPattern.create(rowPattern:get(), nRows:get(), leaveSkippedRowsUnworked:get()))
    end
    course = cg.FieldworkCourse(context)
    course:generate()
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
    textTransform = love.math.newTransform(xOffset, yOffset, 0, 1, 1, 0, 0, 0, 0):scale(scale, scale)
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
    love.window.setMode(windowWidth, windowHeight, { highdpi = true })
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

local function drawText(x, y, color, textScale, ...)
    love.graphics.push()
    love.graphics.setColor(color)
    love.graphics.scale(1, -1)
    love.graphics.print(string.format(...), x, -y, 0, (textScale or 1) / scale)
    love.graphics.pop()
end

---@param block cg.Block
local function drawRows(block)
    for i, r in ipairs(block:getRows()) do
        love.graphics.push()
        love.graphics.setColor(centerColor)
        love.graphics.line(r:getUnpackedVertices())
        love.graphics.setPointSize(pointSize)
        for _, v in r:vertices() do
            drawVertex(v)
        end
        love.graphics.setPointSize(pointSize * 1.5)
        love.graphics.setColor(rowStartColor)
        love.graphics.points(r[1].x, r[1].y)
        love.graphics.setColor(rowEndColor)
        love.graphics.points(r[#r].x, r[#r].y)
        local m = r:getMiddle()
        love.graphics.setColor(centerFontColor)
        love.graphics.scale(1, -1)
        love.graphics.print(i, m.x, -m.y, 0, 1 / scale)
        love.graphics.pop()
    end
end

---@param block cg.Center
local function drawConnectingPaths(center)
    for i, p in ipairs(center:getConnectingPaths()) do
        love.graphics.setLineWidth(10 * lineWidth)
        if #p > 0 then
            love.graphics.setColor(connectingPathColor)
            if #p > 1 then
                love.graphics.line(p:getUnpackedVertices())
            end
            drawText(p[1].x, p[1].y, connectingPathFontColor, 1, '%d - start', i)
            drawText(p[#p].x, p[#p].y, connectingPathFontColor, 1, '%d - end', i)
            love.graphics.setPointSize(pointSize * 6)
            love.graphics.setColor(0, 1, 0, 0.5)
            love.graphics.points(p[1].x, p[1].y)
            love.graphics.setColor(1, 0, 0, 0.5)
            love.graphics.points(p[#p].x, p[#p].y)
        end
    end
end

local function drawBlocks()
    for ib, b in ipairs(course:getCenter():getBlocks()) do
        love.graphics.setColor(blockColor)
        love.graphics.polygon('fill', b:getPolygon():getUnpackedVertices())
        love.graphics.setLineWidth(2 * lineWidth)
        local blockCenter = b:getPolygon():getCenter()
        love.graphics.push()
        love.graphics.setColor(blockFontColor)
        love.graphics.scale(1, -1)
        love.graphics.print(string.format('%d (%d)', ib, b.id), blockCenter.x, -blockCenter.y, 0, 1 / scale)
        love.graphics.pop()
        drawRows(b)
    end
end

local function drawCenter()
    if course:getCenter():getDebugRows() then
        if showDebugInfo:get() then
            for _, r in ipairs(course:getCenter():getDebugRows()) do
                love.graphics.setColor(debugColor)
                love.graphics.setLineWidth(3 * lineWidth)
                love.graphics.line(r:getUnpackedVertices())
            end
        end
    end
    drawBlocks()
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
    drawHeadland(course:getHeadland(), courseColor)
    drawConnectingPaths(course:getCenter())
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

local function drawDebugPolylines()
    if cg.debugPolylines then
        love.graphics.push()
        love.graphics.replaceTransform(graphicsTransform)
        love.graphics.setColor(debugColor)
        love.graphics.setLineWidth(pointSize * 3)
        for _, p in ipairs(cg.debugPolylines) do
            if #p > 1 then
                love.graphics.line(p:getUnpackedVertices())
            end
        end
        love.graphics.pop()
    end
end

function love.draw()
    drawGraphics()
    drawStatus()
    drawContext()
    if showDebugInfo:get() then
        drawDebugPoints()
        drawDebugPolylines()
    end
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
    elseif button == 3 then
        x, y = love.mouse.getPosition()
        baselineX, baselineY = screenToWorld(x, y)
        generate()
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

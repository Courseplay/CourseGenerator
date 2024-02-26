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

local logger = Logger('main', Logger.level.debug)
local parameters = {}
-- working width of the equipment
local workingWidth = AdjustableParameter(24, 'width', 'W', 'w', 0.2, 0, 100)
table.insert(parameters, workingWidth)
local turningRadius = AdjustableParameter(7, 'radius', 'T', 't', 0.2, 0, 20)
table.insert(parameters, turningRadius)
-- number of headland passes around the field boundary
local nHeadlandPasses = AdjustableParameter(3, 'headlands', 'P', 'p', 1, 0, 100)
table.insert(parameters, nHeadlandPasses)
local nHeadlandsWithRoundCorners = AdjustableParameter(0, 'headlands with round corners', 'R', 'r', 1, 0, 100)
table.insert(parameters, nHeadlandsWithRoundCorners)
local headlandClockwise = ToggleParameter('headlands clockwise', true, 'c')
table.insert(parameters, headlandClockwise)
local headlandFirst = ToggleParameter('headlands first', true, 'h')
table.insert(parameters, headlandFirst)
local fieldCornerRadius = AdjustableParameter(6, 'field corner radius', 'F', 'f', 1, 0, 30)
table.insert(parameters, fieldCornerRadius)
local sharpenCorners = ToggleParameter('sharpen corners', true, 's')
table.insert(parameters, sharpenCorners)
local bypassIslands = ToggleParameter('island bypass', true, 'b')
table.insert(parameters, bypassIslands)
local nIslandHeadlandPasses = AdjustableParameter(2, 'island headlands', 'I', 'i', 1, 1, 10)
table.insert(parameters, nIslandHeadlandPasses)
local islandHeadlandClockwise = ToggleParameter('island headlands clockwise', false, 'C')
table.insert(parameters, islandHeadlandClockwise)
local autoRowAngle = ToggleParameter('auto row angle', true, '6')
table.insert(parameters, autoRowAngle)
local rowAngleDeg = AdjustableParameter(-90, 'row angle', 'A', 'a', 10, -90, 90)
table.insert(parameters, rowAngleDeg)
local rowPattern = ListParameter(cg.RowPattern.RACETRACK, 'row pattern', 'O', 'o',
        { cg.RowPattern.ALTERNATING,
          cg.RowPattern.SKIP,
          cg.RowPattern.SPIRAL,
          cg.RowPattern.LANDS,
          cg.RowPattern.RACETRACK
        },
        {
            'alternating',
            'skip',
            'spiral',
            'lands',
            'racetrack'
        })
table.insert(parameters, rowPattern)
local nRows = AdjustableParameter(4, 'rows to skip/rows per land', 'K', 'k', 1, 0, 10)
table.insert(parameters, nRows)
local leaveSkippedRowsUnworked = ToggleParameter('leave skipped rows unworked', false, 'u')
table.insert(parameters, leaveSkippedRowsUnworked)
local centerClockwise = ToggleParameter('spiral/lands clockwise', true, 'l')
table.insert(parameters, centerClockwise)
local spiralFromInside = ToggleParameter('spiral from inside', true, 'L')
table.insert(parameters, spiralFromInside)
local evenRowDistribution = ToggleParameter('even row width', false, 'e')
table.insert(parameters, evenRowDistribution)
local useBaselineEdge = ToggleParameter('use base line edge', false, 'g')
table.insert(parameters, useBaselineEdge)
local showDebugInfo = ToggleParameter('show debug info', false, 'd', true)
table.insert(parameters, showDebugInfo)
local twoSided = ToggleParameter('two sided', false, '2')
table.insert(parameters, twoSided)
local showSwath = ToggleParameter('show swath', false, '1', true)
table.insert(parameters, showSwath)
local reverseCourse = ToggleParameter('reverse', false, 'v', true)
table.insert(parameters, reverseCourse)
local smallOverlaps = ToggleParameter('small overlaps', false, 'm', true)
table.insert(parameters, smallOverlaps)

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
local startX, startY, baselineX, baselineY = 1000, 0, 1000, 0

local graphicsTransform, textTransform, statusTransform, mouseTransform, contextTransform, errorTransform
local startSign, stopSign

local parameterNameColor = { 1, 1, 1 }
local parameterKeyColor = { 0, 1, 1 }
local parameterValueColor = { 1, 1, 0 }

local startLocationColor = { 0.9, 0.9, 0.9 }
local fieldBoundaryColor = { 0.5, 0.5, 0.5 }
local courseColor = { 0, 0.7, 1 }
local turnColor = { 1, 1, 0, 0.5 }
local usePathfinderColor = { 0, 1, 0 }
local islandHeadlandColor = { 1, 1, 1, 0.2 }
local waypointColor = { 0.7, 0.5, 0.2 }
local cornerColor = { 1, 1, 0.0, 0.8 }
local islandBypassColor = { 0, 0.2, 1.0 }
local debugColor = { 1, 0.5, 0.5, 0.7 }
local debugTextColor = { 0.8, 0, 0, 1 }
local warningColor = { 1, 0.5, 0 }
local highlightedWaypointColor = { 0.7, 0.7, 0.7, 1 }
local highlightedWaypointColorForward = { 0, 0.7, 0, 1 }
local highlightedWaypointColorBackward = { 0.7, 0, 0, 1 }
local centerColor = { 0, 0.7, 1, 0.8 }
local centerFontColor = { 0, 0.7, 1 }
local blockColor = { 1, 0.5, 0, 0.2 }
local blockFontColor = { 1, 0.5, 0, 1 }
local rowEndColor = { 0, 1, 0, 1 }
local rowStartColor = { 1, 0, 0, 1 }
local connectingPathColor = { 0.3, 0.3, 0.3, 1 }
local connectingPathFontColor = { 0.8, 0.8, 0.8, 1 }
local swathColor = { 0, 0.7, 0, 0.25 }
local islandColor = { 0.7, 0, 0.7, 1 }
local islandPointColor = { 0.7, 0, 0.7, 0.4 }
local islandPerimeterPointColor = { 1, 0.4, 1 }


-- the selectedField to generate the course for
---@type cg.Field
local selectedField
-- the generated fieldwork course
---@type cg.FieldworkCourse
local course
local savedFields
local currentVertices
local errors = {}
local context
------------------------------------------------------------------------------------------------------------------------
--- Generate the fieldwork course
---------------------------------------------------------------------------------------------------------------------------
local function generate()
    Logger.setLogfile(string.format('log/%s.log', selectedField:getId()))
    cg.clearDebugObjects()
    context = cg.FieldworkContext(selectedField, workingWidth:get(), turningRadius:get(), nHeadlandPasses:get())
                :setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners:get())
                :setHeadlandClockwise(headlandClockwise:get())
                :setIslandHeadlandClockwise(islandHeadlandClockwise:get())
                :setHeadlandFirst(headlandFirst:get())
                :setIslandHeadlands(nIslandHeadlandPasses:get())
                :setFieldCornerRadius(fieldCornerRadius:get())
                :setBypassIslands(bypassIslands:get())
                :setSharpenCorners(sharpenCorners:get())
                :setAutoRowAngle(autoRowAngle:get())
                :setRowAngle(math.rad(rowAngleDeg:get()))
                :setEvenRowDistribution(evenRowDistribution:get())
                :setUseBaselineEdge(useBaselineEdge:get())
                :setStartLocation(startX, startY)
                :setBaselineEdge(startX, startY)
                :setBaselineEdge(baselineX, baselineY)
                :setEnableSmallOverlapsWithHeadland(smallOverlaps:get())
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
    local generatorFunc
    if twoSided:get() then
        generatorFunc = function()
            return cg.FieldworkCourseTwoSided(context)
        end
    else
        generatorFunc = function()
            return cg.FieldworkCourse(context)
        end
    end
    local success
    success, course = xpcall(
            generatorFunc,
            function(err)
                context:addError(logger, debug.traceback(err))
                error(nil)
            end)
    if not success then
        io.stdout:flush()
        errors = context:getErrors()
        return
    end
    if reverseCourse:get() then
        course:reverse()
    end
    if profilerEnabled then
        print(love.profiler.report(40))
        love.profiler.reset()
        love.profiler.stop()
    end
    -- make sure all logs are now visible
    io.stdout:flush()
    errors = context:getErrors()
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
    logger:debug('Reading %s...', fileName)
    savedFields = cg.Field.loadSavedFields(fileName)
    selectedField = savedFields[tonumber(arg[2])]
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
    -- window is 80% of the screen size
    windowWidth, windowHeight = love.window.getDesktopDimensions()
    windowWidth, windowHeight = 0.8 * windowWidth, 0.8 * windowHeight
    -- initially, start in the lower left corner
    startX, startY = x1 + 10, y1 + 10
    local fieldCenter = selectedField:getCenter()
    -- world offset
    --scale = 1
    setOffset(fieldCenter.x, fieldCenter.y)
    updateTransform()
    statusTransform = love.math.newTransform(0, 0, 0, 1, 1, -windowWidth + 200, -windowHeight + 30)
    mouseTransform = love.math.newTransform()
    contextTransform = love.math.newTransform(10, 10, 0, 1, 1, 0, 0)
    errorTransform = love.math.newTransform(300, 0, 0, 1, 1, 0, 0)
    love.graphics.setPointSize(pointSize)
    love.graphics.setLineWidth(lineWidth)
    love.window.setMode(windowWidth, windowHeight, { highdpi = true })
    love.window.setTitle(string.format('Course Generator - %s', selectedField:getId()))

    startSign = love.graphics.newImage('Courseplay_FS22/img/signs/start.dds')
    stopSign = love.graphics.newImage('Courseplay_FS22/img/signs/stop.dds')

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
    local vertices = {}
    for _, v in polygon:vertices() do
        if math.abs(v.x - rx) < 1 and math.abs(v.y - ry) < 1 then
            table.insert(vertices, v)
        end
    end
    return vertices
end

local function findCurrentVertices(sx, sy)
    local x, y = screenToWorld(sx, sy)
    if course and not context:hasErrors() then
        return findVertexForPosition(course:getPath(), x, y)
    end
end

local function selectFieldUnderCursor()
    local x, y = love.mouse.getPosition()
    startX, startY = screenToWorld(x, y)
    for _, f in pairs(savedFields) do
        if f:getBoundary():isInside(startX, startY) then
            print(string.format('Field %s selected', f:getId()))
            selectedField = f
            love.window.setTitle(string.format('Course Generator - %s', selectedField:getId()))
            generate()
        end
    end
end

local function drawVertexAsArrow(v)
    local left, right, back = -0.8, 0.8, -0.5
    local triangle = { left, 0, right, 0, 0, 1.6 }
    love.graphics.push()
    love.graphics.translate(v.x, v.y)
    love.graphics.rotate((v:getExitEdge() or v:getEntryEdge()):getHeading() - math.pi / 2)
    love.graphics.polygon('fill', triangle)
    if v:getAttributes():isLeftSideNotWorked() then
        love.graphics.line({1.5 * left, back, 0, back})
    end
    if v:getAttributes():isRightSideNotWorked() then
        love.graphics.line({1.5 * right, back, 0, back})
    end
    love.graphics.pop()
end

local function drawWaypoint(v)
    if v.color then
        love.graphics.setColor(v.color)
    else
        love.graphics.setColor(waypointColor)
    end
    if v:getAttributes():isHeadlandTurn() then
        love.graphics.setColor(cornerColor)
    end
    if v:getAttributes():isIslandBypass() then
        love.graphics.setColor(islandBypassColor)
    end
    if v:getAttributes():isRowStart() then
        love.graphics.setColor(rowStartColor)
    elseif v:getAttributes():isRowEnd() then
        love.graphics.setColor(rowEndColor)
    end
    drawVertexAsArrow(v)
end

local function drawPath(p)
    if #p > 1 then
        for i, v in p:vertices() do
            if v:getExitEdge() then
                if v:getAttributes():shouldUsePathfinderToNextWaypoint() then
                    love.graphics.setLineWidth(5 * lineWidth)
                    love.graphics.setColor(usePathfinderColor)
                elseif v:getAttributes():isRowEnd() then
                    love.graphics.setLineWidth(lineWidth)
                    love.graphics.setColor(turnColor)
                else
                    love.graphics.setLineWidth(lineWidth)
                    love.graphics.setColor(courseColor)
                end
                love.graphics.line(v.x, v.y, v:getExitEdge():getEnd().x, v:getExitEdge():getEnd().y)
            end
            if v:getEntryEdge() and v:getAttributes():shouldUsePathfinderToThisWaypoint() then
                love.graphics.setLineWidth(5 * lineWidth)
                love.graphics.setColor(usePathfinderColor)
                love.graphics.line(v.x, v.y, v:getEntryEdge():getBase().x, v:getEntryEdge():getBase().y)
            end
            if p[i + 1] and v:almostEquals(p[i + 1]) then
                -- two subsequent vertices have the same position
                love.graphics.setColor(warningColor)
                love.graphics.circle('line', v.x, v.y, 2)
            end
            drawWaypoint(v)
        end
        love.graphics.push()
        love.graphics.scale(1, -1)
        local signScale = 0.03
        love.graphics.draw(startSign, p[1].x - 2, -p[1].y - 2, 0, signScale, signScale)
        love.graphics.draw(stopSign, p[#p].x - 2, -p[#p].y - 2, 0, signScale, signScale)
        love.graphics.pop()
    end
end

local function drawSwath(p)
    if showSwath:get() then
        if #p > 1 then
            love.graphics.setLineWidth(workingWidth:get())
            for i, v in p:vertices() do
                -- when hovering over a vertex, show the swath up
                if currentVertices and currentVertices[1] and currentVertices[1].ix <= i then
                    break
                end
                if v:getExitEdge() then
                    if not v:getAttributes():isRowEnd() then
                        love.graphics.setColor(swathColor)
                        love.graphics.line(v.x, v.y, v:getExitEdge():getEnd().x, v:getExitEdge():getEnd().y)
                    end
                end
            end
        end
    end
end

local function drawIslandHeadland(h, color)
    love.graphics.setLineWidth(10 * lineWidth)
    love.graphics.setColor(color)
    if h:isValid() then
        love.graphics.polygon('line', h:getUnpackedVertices())
    end
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
        love.graphics.setPointSize(pointSize * 1.5)
        local m = r:getMiddle()
        love.graphics.setColor(centerFontColor)
        love.graphics.scale(1, -1)
        love.graphics.print(i, m.x, -m.y, 0, 1 / scale)
        love.graphics.pop()
    end
end

---@param block cg.Center
local function drawConnectingPaths(center)
    if center == nil or center:getConnectingPaths() == nil then
        return
    end
    for i, p in ipairs(center:getConnectingPaths()) do
        love.graphics.setLineWidth(10 * lineWidth)
        if #p > 0 then
            love.graphics.setColor(connectingPathColor)
            if #p > 1 then
                love.graphics.line(p:getUnpackedVertices())
            end
            love.graphics.setPointSize(pointSize * 6)
            love.graphics.setColor(0, 1, 0, 0.3)
            love.graphics.points(p[1].x, p[1].y)
            love.graphics.setColor(1, 0, 0, 0.3)
            love.graphics.points(p[#p].x, p[#p].y)
            drawText(p[1].x, p[1].y, connectingPathFontColor, 1, '%d - start', i)
            drawText(p[#p].x, p[#p].y, connectingPathFontColor, 1, '%d - end', i)
        end
    end
end

local function drawBlocks(center)
    for ib, b in ipairs(center:getBlocks()) do
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

local function drawCenter(center)
    if center:getDebugRows() then
        if showDebugInfo:get() then
            for _, r in ipairs(course:getCenter():getDebugRows()) do
                love.graphics.setColor(debugColor)
                love.graphics.setLineWidth(3 * lineWidth)
                love.graphics.line(r:getUnpackedVertices())
            end
        end
    end
    drawBlocks(center)
end

local function drawFields()
    for _, f in pairs(savedFields) do
        love.graphics.setLineWidth(lineWidth)
        love.graphics.setColor(fieldBoundaryColor)
        local unpackedVertices = f:getUnpackedVertices()
        if #unpackedVertices > 2 then
            love.graphics.polygon('line', unpackedVertices)
            for _, v in ipairs(f:getBoundary()) do
                love.graphics.points(v.x, v.y)
            end
            for _, i in ipairs(f:getIslands()) do
                love.graphics.setColor(islandColor)
                love.graphics.setLineWidth(lineWidth)
                if #i:getBoundary() > 2 then
                    love.graphics.polygon('line', i:getBoundary():getUnpackedVertices())
                end
                local islandHeadlands = i:getHeadlands();
                for _, h in ipairs(islandHeadlands) do
                    drawIslandHeadland(h, islandHeadlandColor)
                end

                love.graphics.setColor(islandColor)
                local c = i:getBoundary():getCenter()
                love.graphics.push()
                love.graphics.scale(1, -1)
                love.graphics.print(i:getId(), c.x, -c.y)
                love.graphics.pop()
            end
        end

        love.graphics.setColor(fieldBoundaryColor)
        local c = f:getCenter()
        love.graphics.push()
        love.graphics.scale(1, -1)
        love.graphics.print(f:getNum(), c.x, -c.y)
        love.graphics.pop()
    end
end

local function drawHeadlands()
    --drawHeadland(course:getHeadlandPath(), courseColor)
    drawConnectingPaths(course:getCenter())
end

-- Draw a tooltip with the vertex' details
local function drawVertexInfo()
    love.graphics.replaceTransform(mouseTransform)
    local text = ''
    for i, v in ipairs(currentVertices) do
        if i > 1 then
            text = text .. '---\n'
        end
        text = text .. string.format('ix: %s\n', intToString(v.ix))
        text = text .. string.format('r: %s xte: %s\n', floatToString(v:getSignedRadius()),
                floatToString(v:getXte(turningRadius:get())))
        text = text .. string.format('corner: %s\n', v.isCorner)
        text = text .. string.format('x: %s y: %s\n', floatToString(v.x), floatToString(v.y))
        text = text .. tostring(v:getAttributes()) .. '\n'
    end
    local width, margin = 300, 10
    local _, wrappedText = love.graphics.getFont():getWrap(text, width - 2 * margin)
    local h = love.graphics.getFont():getHeight()
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle('fill', 0, 0, width, (#wrappedText + 1) * h)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf(text, margin, h, width - 2 * margin)
end

-- Highlight a few vertices around the selected one
local function highlightPathAroundVertex(v)
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setLineWidth(lineWidth)
    for i = v.ix - 20, v.ix + 30 do
        love.graphics.setColor(i == v.ix and highlightedWaypointColor or
                (i < v.ix and highlightedWaypointColorBackward or highlightedWaypointColorForward))
        local p = course:getPath():at(i)
        if p then
            love.graphics.circle('line', p.x, p.y, 1.5)
        end
    end
end

local function highlightPathToNextRow(vertices)
    for i, v in ipairs(vertices) do
        if v:getAttributes():isRowEnd() then
            local innermostHeadland = course:findPathToNextRow(v:getAttributes():getAtBoundaryId(),
                    v, course:getPath()[v.ix + 1], turningRadius:get())
            if #innermostHeadland > 1 then
                love.graphics.replaceTransform(graphicsTransform)
                love.graphics.setLineWidth(10 * lineWidth)
                love.graphics.setColor({1, 1, 0, 0.3})
                love.graphics.line(innermostHeadland:getUnpackedVertices())
            end
        end
    end
end

local function drawStartLocation()
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setColor(startLocationColor)
    love.graphics.setLineWidth(lineWidth)
    love.graphics.circle('line', startX, startY, 2)
    love.graphics.push()
    love.graphics.scale(1, -1)
    love.graphics.print('Start location', startX + 2, -startY, 0, 1 / scale)
    love.graphics.pop()
end

local function drawGraphics()
    love.graphics.replaceTransform(graphicsTransform)
    love.graphics.setPointSize(pointSize)
    drawFields()
    if course and not context:hasErrors() then
        drawHeadlands()
        if course:getCenter() then
            drawCenter(course:getCenter())
        end
        drawPath(course:getPath())
        drawSwath(course:getPath())
    end
    drawStartLocation()
end

local function drawContext()
    love.graphics.replaceTransform(contextTransform)
    love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    local fontsize = 12
    local y = 0
    love.graphics.rectangle('fill', 0, 0, 300, (3 + #parameters) * fontsize)
    love.graphics.setColor(1, 1, 1) -- base color for the coloredText is white (love2D can sometimes be strange)
    love.graphics.print({ parameterNameColor, 'To generate, hit ', parameterKeyColor, 'SPACE or right click' }, 0, y)
    y = y + fontsize
    love.graphics.print({ parameterNameColor, 'To mark baseline edge ', parameterKeyColor, 'hold SHIFT + right click' }, 0, y)
    y = y + 2 * fontsize
    for _, p in ipairs(parameters) do
        love.graphics.print(p:toColoredText(parameterNameColor, parameterKeyColor, parameterValueColor), 0, y)
        y = y + fontsize
    end
end

local function drawErrors()
    if #errors > 0 then
        love.graphics.replaceTransform(errorTransform)
        love.graphics.setColor(1, 0, 0)
        local fontsize = 12
        love.graphics.rectangle('fill', 0, 0, 600, (3 + #errors) * fontsize)
        love.graphics.setColor(1, 1, 1) -- base color for the coloredText is white (love2D can sometimes be strange)
        local y = 2 * fontsize
        for _, e in ipairs(errors) do
            love.graphics.print(e, 0, y)
            y = y + fontsize
        end
    end
end

local function drawStatus()
    love.graphics.setColor(1, 1, 0)
    love.graphics.replaceTransform(statusTransform)
    local mx, my = love.mouse.getPosition()
    local x, y = screenToWorld(mx, my)
    love.graphics.print(string.format('%.1f %.1f (%.1f %.1f / %.1f)', x, y, xOffset, yOffset, scale), 0, 0)
    if currentVertices and #currentVertices > 0 then
        highlightPathAroundVertex(currentVertices[1])
        drawVertexInfo(currentVertices)
        highlightPathToNextRow(currentVertices)
    end
end

local function drawDebugPoints()
    if cg.debugPoints then
        for _, p in ipairs(cg.debugPoints) do
            love.graphics.setColor(p.debugColor or debugColor)
            love.graphics.replaceTransform(graphicsTransform)
            love.graphics.setPointSize(p.small and pointSize * 0.3 or pointSize * 3)
            love.graphics.points(p.x, p.y)
            if p.debugText then
                drawText(p.x + 1, p.y + 1, debugTextColor, 1, p.debugText)
            end
        end
    end
end

local function drawDebugPolylines()
    if cg.debugPolylines then
        love.graphics.push()
        love.graphics.replaceTransform(graphicsTransform)
        love.graphics.setPointSize(pointSize)
        love.graphics.setLineWidth(pointSize)
        for _, p in ipairs(cg.debugPolylines) do
            if #p > 1 then
                love.graphics.setColor(debugColor)
                love.graphics.line(p:getUnpackedVertices())
                local color = p.debugColor or debugColor
                love.graphics.setColor(color)
                for i, v in ipairs(p) do
                    drawVertexAsArrow(v)
                    drawText(v.x + 1, v.y + 1, color, 1, i)
                end
            end
        end
        love.graphics.pop()
    end
end

function love.draw()
    drawGraphics()
    drawStatus()
    drawContext()
    drawErrors()
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
        p:onKey(key, function()
            return true
        end)
    end
    if key == ' ' then
        generate()
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
    elseif button == 2 and not love.keyboard.isDown('lshift') then
        selectFieldUnderCursor()
    elseif button == 3 or (button == 2 and love.keyboard.isDown('lshift')) then
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
    currentVertices = findCurrentVertices(x, y)
end

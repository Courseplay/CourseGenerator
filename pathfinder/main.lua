--[[

LOVE app to test the Courseplay turn maneuvers and pathfinding

]]--

dofile( 'include.lua' )
require('mocks.mock-GiantsEngine')
require('mocks.mock-Node')
require('mocks.mock-DebugUtil')
require('mocks.mock-Courseplay')
require('CpUtil')
require('BinaryHeap')
require('ReedsShepp')
require('ReedsSheppSolver')
require('Waypoint')
require('Course')
require('ai.util.AIUtil')
require('pathfinder.pathfinder')
dofile('pathfinder/network.lua')

local parameterNameColor = { 1, 1, 1 }
local parameterKeyColor = { 0, 1, 1 }
local parameterValueColor = { 1, 1, 0 }

local startHeading = 2 * math.pi / 4
local startPosition = State3D(185, 135, startHeading, 0)
local lastStartPosition = State3D.copy(startPosition)

local goalHeading = 6 * math.pi / 4
local goalPosition = State3D(126, 100, goalHeading, 0)
local lastGoalPosition = State3D.copy(goalPosition)

local vehicle

local parameters = {}
local workWidth = AdjustableParameter(3, 'width', 'W', 'w', 0.5, 2, 40)
table.insert(parameters, workWidth)
local turningRadius = AdjustableParameter(9.3, 'turning radius', 'R', 'r', 0.2, -20, 10)
table.insert(parameters, turningRadius)

local hybrid = ToggleParameter('hybrid', true, 'h')
table.insert(parameters, hybrid)
local penalty = AdjustableParameter(20, 'Penalty', 'P', 'p', 5, -100, 100)
table.insert(parameters, penalty)
    local stepSize = AdjustableParameter(1, 'Dubins step size', 'D', 'd', 0.05, 0.1, 2)
table.insert(parameters, stepSize)

startPosition:setTrailerHeading(startHeading)

local scale, width, height = 5, 800, 360
local xOffset, yOffset = -100 + width / scale / 4, 100 + height / scale

local vehicleData ={name = 'name', turningRadius = turningRadius:get(), dFront = 4, dRear = 2, dLeft = 1.5, dRight = 1.5}
local trailerData ={name = 'name', turningRadius = turningRadius:get(), dFront = 3, dRear = 7, dLeft = 1.5, dRight = 1.5, hitchLength = 10}

local dragging = false
local startTime

local dubinsPath = {}
local rsPath = {}
local rsSolver = ReedsSheppSolver()
local dubinsSolver = DubinsSolver()

local currentHighlight = 1
local currentPathfinderIndex = 1
local done, path, goalNodeInvalid

local nTotalNodes = 0
local nStartNodes = 0
local nMiddleNodes = 0
local nEndNodes = 0

local line = {}

local function find(start, goal, allowReverse)
    startTime = love.timer.getTime()
    start:setTrailerHeading(start.t)
    local dubinsSolution = dubinsSolver:solve(start, goal, turningRadius:get())
    dubinsPath = dubinsSolution:getWaypoints(start, turningRadius:get())
    local rsActionSet = rsSolver:solve(start, goal, turningRadius:get(), {ReedsShepp.PathWords.LbRfLb})
    if rsActionSet:getLength(turningRadius:get()) < 100 then rsPath = rsActionSet:getWaypoints(start, turningRadius:get()) end
    TestPathfinder.setNodePenalty(penalty:get())
    TestPathfinder.setHybridRange(hybrid:get() and 20 or math.huge)
    TestPathfinder.start(start, goal, turningRadius:get())
    io.stdout:flush()
	lastStartPosition = State3D.copy(startPosition)
	lastGoalPosition = State3D.copy(goalPosition)
    return done, path, goalNodeInvalid
end

local dtTotal = 0

function love.update(dt)
    TestPathfinder.update()
    dtTotal = dtTotal + dt
    if dtTotal > 0.5 then
        dtTotal = 0
    end
end

function love.load()
	love.window.setMode(1000, 700)
	love.graphics.setPointSize(3)
	find(startPosition, goalPosition)
end

local logger = Logger()

local function debug(...)
    logger:debug(...)
end

local function love2real( x, y )
    return ( x / scale ) - xOffset,  - ( y / scale ) + yOffset
end

local function drawContext()

end

local function drawVehicle(p, i)
    local v = getVehicleRectangle(p, vehicleData, p.t, 0)
    local r, g, b = 0.4, 0.4, 0
    local highlight = i == currentHighlight and 0.4 or 0
    love.graphics.setColor( 0, g + highlight, 0 )
    love.graphics.line(v[1].x, v[1].y, v[2].x, v[2].y)
    love.graphics.setColor( r + highlight, g + highlight, 0 )
    love.graphics.line(v[2].x, v[2].y, v[3].x, v[3].y)
    love.graphics.setColor( r + g, 0, 0 )
    love.graphics.line(v[3].x, v[3].y, v[4].x, v[4].y)
    love.graphics.setColor( 0, r + highlight, g + highlight )
    love.graphics.line(v[4].x, v[4].y, v[1].x, v[1].y)
    v = getVehicleRectangle(p, trailerData, p.tTrailer, -trailerData.dFront)
    love.graphics.setColor( 0, 0.3 + highlight, 0 )
    love.graphics.line(v[1].x, v[1].y, v[2].x, v[2].y)
    love.graphics.setColor( 0, 0, 0.6 + highlight )
    love.graphics.line(v[2].x, v[2].y, v[3].x, v[3].y)
    love.graphics.setColor( 0.3 + highlight, 0, 0 )
    love.graphics.line(v[3].x, v[3].y, v[4].x, v[4].y)
    love.graphics.setColor( 0, 0, 0.6 + highlight )
    love.graphics.line(v[4].x, v[4].y, v[1].x, v[1].y)
end

---@param node State3D
local function drawNode(node)
    love.graphics.push()
    love.graphics.translate(node.x, node.y)
    love.graphics.rotate(node.t)
    local left, right = -1.0, 1.0
    local triangle = { 0, left, 0, right, 4, 0}
    love.graphics.polygon( 'line', triangle )
    love.graphics.pop()
end

---@param path State3D[]
local function drawPath(path, pointSize, r, g, b)
    if path then
        love.graphics.setPointSize(pointSize)
        for i = 2, #path do
            love.graphics.setColor(r, g, b)
            love.graphics.line(path[i - 1].x, path[i - 1].y, path[i].x, path[i].y)
        end
    end
end

local function drawProhibitedAreas()
    love.graphics.setColor(0.2, 0.2, 0.2)
    for _, p in ipairs(TestPathfinder.getProhibitedPolygons()) do
        love.graphics.polygon('line', p:getUnpackedVertices())
    end
end

local function drawPathFinderNodes()
    local function drawOne(cell, highestCost, lowestCost, alpha)
        if cell.pred == cell then
            love.graphics.setPointSize(5)
            love.graphics.setColor(0, 0.3, 0.3, alpha)
        else
            local range = highestCost - lowestCost
            local color = (cell.cost - lowestCost) / range
            love.graphics.setPointSize(1)
            if cell:isClosed() or true then
                love.graphics.setColor(0.3 + color, 1 - color, 0, alpha)
            else
                love.graphics.setColor(cell.cost / range, 0.2, 0, alpha)
            end
        end
        if cell.pred then
            love.graphics.setLineWidth(0.1)
            love.graphics.line(cell.x, cell.y, cell.pred.x, cell.pred.y)
        else
            love.graphics.setPointSize(3)
            love.graphics.points(cell.x, cell.y)
        end
        nTotalNodes = nTotalNodes + 1
    end

    nTotalNodes = 0
    local alpha = 1 - math.min(0.9, nStartNodes / 1000)
    nStartNodes = 0
    for cell, lowestCost, highestCost in TestPathfinder.getNodeIteratorStart() do
        drawOne(cell, highestCost, lowestCost, alpha)
        nStartNodes = nStartNodes + 1
    end
    alpha = 1 - math.min(0.3, nMiddleNodes / 1000)
    nMiddleNodes = 0
    for cell, lowestCost, highestCost in TestPathfinder.getNodeIteratorMiddle() do
        drawOne(cell, highestCost, lowestCost, alpha)
        nMiddleNodes = nMiddleNodes + 1
    end
    alpha = 1 - math.min(0.9, nEndNodes / 1000)
    nEndNodes = 0
    for cell, lowestCost, highestCost in TestPathfinder.getNodeIteratorEnd() do
        drawOne(cell, highestCost, lowestCost, alpha)
        nEndNodes = nEndNodes + 1
    end
end

local function drawGrid(gridSize)
    local n = 50
    for x = -n * gridSize, n * gridSize, gridSize do
        love.graphics.line(x, -n * gridSize, x, n * gridSize)
        love.graphics.line(-n * gridSize, x, n * gridSize, x)
    end
end

local function showStatus()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    local fontsize = 12
    local y = 0
    love.graphics.rectangle('fill', 0, 0, 300, (5 + #parameters) * fontsize)
    love.graphics.setColor(1, 1, 1) -- base color for the coloredText is white (love2D can sometimes be strange)
    for _, p in ipairs(parameters) do
        love.graphics.print(p:toColoredText(parameterNameColor, parameterKeyColor, parameterValueColor), 0, y)
        y = y + fontsize
    end
    y = y + fontsize
    love.graphics.print(string.format('Start nodes: %d', nStartNodes), 0, y)
    y = y + fontsize
    love.graphics.print(string.format('Middle nodes: %d', nMiddleNodes), 0, y)
    y = y + fontsize
    love.graphics.print(string.format('End nodes: %d', nEndNodes), 0, y)
    y = y + fontsize
    love.graphics.print(string.format('Total nodes: %d', nTotalNodes), 0, y)
    y = y + fontsize
    love.graphics.print(string.format('Calls to getNodePenalty(): %d', TestPathfinder.getPenaltyCalls()), 0, y)
    y = y + fontsize

    if path then
        if constraints:isValidNode(path[math.min(#path, currentHighlight)]) then
            love.graphics.print('VALID', 10, 20)
        else
            love.graphics.print('NOT VALID', 10, 20)
        end
    end
    local mx, my = love.mouse.getPosition()
    local x, y = love2real(mx, my)
    love.graphics.print(string.format('%.1f %.1f (%.1f %.1f / %.1f)', x, y, xOffset, yOffset, scale), width - 100, 0)
end

function love.draw()
	if not startPosition == lastStartPosition or not goalPosition == lastGoalPosition then
		find(startPosition, goalPosition)
	end

    love.graphics.push()
    love.graphics.scale(scale, -scale)
    love.graphics.translate(xOffset, -yOffset)

    love.graphics.setColor( 0.2, 0.2, 0.2 )
    love.graphics.setLineWidth(0.2)
    love.graphics.line(-1000, 0, 1000, 0)
    love.graphics.line(0, -1000, 0, 1000)
    love.graphics.setColor( 0.2, 0.2, 0.2, 0.5)
    love.graphics.setLineWidth(0.1)
    drawGrid(3)

    love.graphics.setColor( 0, 1, 0 )
    love.graphics.setPointSize(3)
    love.graphics.points(line)

    love.graphics.setColor(0.0, 0.8, 0.0)
    drawNode(startPosition)
    love.graphics.setColor(0.8, 0.0, 0.0)
    drawNode(goalPosition)
    love.graphics.setColor(0, 0.8, 0)

    love.graphics.setPointSize(5)
    drawProhibitedAreas()
    drawPathFinderNodes()

    --drawPath(dubinsPath, 3, 0.8, 0.8, 0)
    --drawPath(rsPath, 2, 0, 0.3, 0.8)
    if TestPathfinder.getPath() then
        drawPath(TestPathfinder.getPath(), 0.3, 0, 0.6, 1)
    end

    if path then
        love.graphics.setPointSize(0.5 * scale)
        for i = 2, #path do
            local p = path[i]
            if p.gear == Gear.Backward then
                love.graphics.setColor(0, 0.4, 1)
            elseif p.gear == Gear.Forward then
                love.graphics.setColor( 1, 1, 1 )
            else
                love.graphics.setColor(0.4, 0, 0)
            end
            love.graphics.setLineWidth(0.1)
            love.graphics.line(p.x, p.y, path[i-1].x, path[i - 1].y)
            --love.graphics.points(p.x, p.y)
            drawVehicle(p, i)
        end
    end
    drawGraph()

	love.graphics.setColor( 0.3, 0.3, 0.3 )
    love.graphics.pop()


    showStatus()
end

function love.keypressed(key, scancode, isrepeat)
    local headingStepDeg = 15
    if key == 'left' then
        if love.keyboard.isDown('lshift') then
            startPosition:addHeading(math.rad(headingStepDeg))
        else
            goalPosition:addHeading(math.rad(headingStepDeg))
        end
    elseif key == 'right' then
        if love.keyboard.isDown('lshift') then
            startPosition:addHeading(-math.rad(headingStepDeg))
        else
            goalPosition:addHeading(-math.rad(headingStepDeg))
        end
    end
    io.stdout:flush()
end

function love.textinput(key)
    for _, p in pairs(parameters) do
        p:onKey(key, function()
            find(startPosition, goalPosition)
        end)
    end
    if key == ' ' then
        find(startPosition, goalPosition)
    end
end

function love.mousepressed(x, y, button, istouch)
    -- left shift + left click: find path forward only,
    -- left ctrl + left click: find path with reversing allowed
    if button == 1 then
        if love.keyboard.isDown('lshift') or love.keyboard.isDown('lctrl') then
            goalPosition.x, goalPosition.y = love2real( x, y )
            --print(love.profiler.report(profilerReportLength))
            done, path, goalNodeInvalid = find(startPosition, goalPosition, love.keyboard.isDown('lctrl'))

            if path then
                debug('Path found with %d nodes', #path)
            elseif done then
                debug('No path found')
                if goalNodeInvalid then
                    debug('Goal node invalid')
                end
            end
        elseif love.keyboard.isDown('lalt') then
            startPosition.x, startPosition.y = love2real( x, y )
        else
            dragging = true
        end
        io.stdout:flush()
    end
end

function love.mousereleased(x, y, button, istouch)
    if button == 1 then
        dragging = false
    end
end

function love.mousemoved( x, y, dx, dy )
    if dragging then
        xOffset = xOffset + dx / scale
        yOffset = yOffset + dy / scale
    end
end

function love.wheelmoved( dx, dy )
    xOffset = xOffset + dy / scale / 2
    yOffset = yOffset - dy / scale / 2
    scale = scale + scale * dy * 0.05
end

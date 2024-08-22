--[[

LOVE app to test the Courseplay turn maneuvers and pathfinding

]]--

dofile( 'include.lua' )
require('mock-GiantsEngine')
require('mock-Node')
require('mock-DebugUtil')
require('mock-Courseplay')
require('CpUtil')
require('ReedsShepp')
require('ReedsSheppSolver')
require('TurnTestHelper')
require('Waypoint')
require('Course')
require('ai.turns.Corner')
require('ai.turns.TurnContext')
require('ai.turns.TurnManeuver')
require('PathfinderUtil')
require('ai.AIUtil')

local parameterNameColor = { 1, 1, 1 }
local parameterKeyColor = { 0, 1, 1 }
local parameterValueColor = { 1, 1, 0 }

local startHeading = 2 * math.pi / 4
local startPosition = State3D(0, 0, startHeading, 0)
local lastStartPosition = State3D.copy(startPosition)

local goalHeading = 6 * math.pi / 4
local goalPosition = State3D(15, 0, goalHeading, 0)
local lastGoalPosition = State3D.copy(goalPosition)

local vehicle, turnStartIx, turnContext
-- length of the 180 course
local courseLength = 20

local parameters = {}
local workWidth = AdjustableParameter(6, 'width', 'W', 'w', 0.5, 2, 40)
table.insert(parameters, workWidth)
local turningRadius = AdjustableParameter(5.6, 'turning radius', 'R', 'r', 0.2, -20, 10)
table.insert(parameters, turningRadius)
local distanceToFieldEdge = AdjustableParameter(10, 'distance to field edge', 'E', 'e', 0.5, 0, 40)
table.insert(parameters, distanceToFieldEdge)
local backMarkerDistance = AdjustableParameter(-2.8, 'back marker', 'B', 'b', 0.2, -20, 10)
table.insert(parameters, backMarkerDistance)
local frontMarkerDistance = AdjustableParameter(-3.3, 'front marker', 'F', 'f', 0.2, -20, 10)
table.insert(parameters, frontMarkerDistance)
local steeringLength = AdjustableParameter(5, 'steering length', 'S', 's', 0.2, 0, 20)
table.insert(parameters, steeringLength)
local zOffset = AdjustableParameter(0, 'zOffset', 'Z', 'z', 0.5, -40, 40)
table.insert(parameters, zOffset)
local angleDeg = AdjustableParameter(0, 'angle', 'A', 'a', 10, -90, 90)
table.insert(parameters, angleDeg)

startPosition:setTrailerHeading(startHeading)

local scale, width, height = 30, 800, 360
local xOffset, yOffset = width / scale / 4 - 20, height / scale + 25

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

local line = {}
local courses = {}
local turnContexts = {}
local turnCourses = {}

local function find(start, goal, allowReverse)
    startTime = love.timer.getTime()
    start:setTrailerHeading(start.t)
    local dubinsSolution = dubinsSolver:solve(start, goal, turningRadius:get())
    dubinsPath = dubinsSolution:getWaypoints(start, turningRadius:get())
    local rsActionSet = rsSolver:solve(start, goal, turningRadius:get(), {ReedsShepp.PathWords.LbRfLb})
    if rsActionSet:getLength(turningRadius:get()) < 100 then rsPath = rsActionSet:getWaypoints(start, turningRadius:get()) end
    io.stdout:flush()
	lastStartPosition = State3D.copy(startPosition)
	lastGoalPosition = State3D.copy(goalPosition)
    return done, path, goalNodeInvalid
end

local function calculateTractorCourse(implementCourse)
    local tractorPath = {}
    for _, wp in ipairs(implementCourse.waypoints) do
        local v = PathfinderUtil.getWaypointAsState3D(wp, 0, steeringLength:get())
        table.insert(tractorPath, v)
    end
    return Course.createFromAnalyticPath(vehicle, tractorPath)
end

local function calculateTurn()
	vehicle = TurnTestHelper.createVehicle('test vehicle')
    turnCourses = {}

    -- Headland turn ------------
	local x, z = 0, -20
	courses[1], turnStartIx = TurnTestHelper.createCornerCourse(vehicle, x, z, angleDeg:get())
	turnContext = TurnTestHelper.createTurnContext(vehicle, courses[1], turnStartIx, workWidth:get(), frontMarkerDistance:get(), backMarkerDistance:get())
	turnContexts[1] = turnContext
	--turnCourses[1] = HeadlandCornerTurnManeuver(vehicle, turnContext, turnContext.vehicleAtTurnStartNode, turningRadius:get(),
	--	workWidth:get(), steeringLength:get() > 0, steeringLength:get()):getCourse()

    -- 180 turn ------------
	x, z = 0, 20
	courses[2], turnStartIx = TurnTestHelper.create180Course(vehicle, x, z, workWidth:get(), courseLength, zOffset:get())
	turnContext = TurnTestHelper.createTurnContext(vehicle, courses[2], turnStartIx, workWidth:get(), frontMarkerDistance:get(), backMarkerDistance:get())
	turnContexts[2] = turnContext

    vehicle.getAIDirectionNode = function () return turnContext.vehicleAtTurnStartNode end
	AIUtil = {
        getOffsetForTowBarLength = AIUtil.getOffsetForTowBarLength,
		getTowBarLength = function () return steeringLength:get() end,
		canReverse = function () return true end,
		getReverserNode = function () return end
	}
	x, _, z = localToWorld(turnContext.vehicleAtTurnStartNode, 0, 0, 0)
	local x2, _, _ = localToWorld(turnContext.workEndNode, 0, 0, 0)
	-- distanceToFieldEdge is measured from the turn waypoints, not from the vehicle here in the test tool,
	-- therefore, we need to add the distance between the turn end and the vehicle to calculate the distance
	-- in front of the vehicle. This calculation works only in this tool as the 180 turn course is in the x direction...
    if distanceToFieldEdge:get() > workWidth:get() then
        table.insert(turnCourses, DubinsTurnManeuver(vehicle, turnContext, turnContext.vehicleAtTurnStartNode,
                turningRadius:get(), workWidth:get(), steeringLength:get(), distanceToFieldEdge:get() + x2 - x):getCourse())
        for _, wp in ipairs(turnCourses[#turnCourses].waypoints) do
            print(wp.calculatedRadius)
        end
    else
        table.insert(turnCourses, ReedsSheppTurnManeuver(vehicle, turnContext, turnContext.vehicleAtTurnStartNode,
                turningRadius:get(), workWidth:get(), steeringLength:get(), distanceToFieldEdge:get() + x2 - x):getCourse())
    end

    --table.insert(turnCourses, calculateTractorCourse(turnCourses[#turnCourses]))
end

function love.load()
	love.window.setMode(1000, 700)
	love.graphics.setPointSize(3)
	calculateTurn()
	--find(startPosition, goalPosition)
end

local function debug(...)
    print(string.format(...))
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

local function drawCourse(course, lineWidth, pointSize, r, g, b)
	if course then
		love.graphics.setLineWidth(lineWidth)
		for i = 1, #course do
			local cp, pp = course[i], course[i - 1]
			if r then
				love.graphics.setColor(r, g, b, 0.2)
				if pp then love.graphics.line(pp.z, pp.x, cp.z, cp.x) end
			elseif cp.rev then
				love.graphics.setColor(0, 0.3, 1, 1)
				love.graphics.print(string.format('%d', i), cp.z, cp.x, 0, 0.04, -0.04, 15, 15)
				love.graphics.setColor(0, 0, 1, 0.5)
				if pp then love.graphics.line(pp.z + 0.1, pp.x + 0.1, cp.z + 0.1, cp.x + 0.1) end
			else
				love.graphics.setColor(0.2, 1, 0.2, 1)
				love.graphics.print(string.format('%d', i), cp.z, cp.x, 0, 0.04, -0.04, -5, -5)
				love.graphics.setColor(0.2, 1, 0.2, 0.5)
				if pp then love.graphics.line(pp.z, pp.x, cp.z, cp.x) end
			end
			love.graphics.setPointSize(pointSize)
			if cp.turnStart then
				love.graphics.setColor(0, 1, 0)
				love.graphics.points(cp.z, cp.x)
			end
			if cp.turnEnd then
				love.graphics.setColor(1, 0, 0)
				love.graphics.points(cp.z, cp.x)
			end
		end
	end
end

local function showStatus()
    love.graphics.setColor(0.2, 0.2, 0.2, 0.6)
    local fontsize = 12
    local y = 0
    love.graphics.rectangle('fill', 0, 0, 300, (3 + #parameters) * fontsize)
    love.graphics.setColor(1, 1, 1) -- base color for the coloredText is white (love2D can sometimes be strange)
    for _, p in ipairs(parameters) do
        love.graphics.print(p:toColoredText(parameterNameColor, parameterKeyColor, parameterValueColor), 0, y)
        y = y + fontsize
    end

    if path then
        if constraints:isValidNode(path[math.min(#path, currentHighlight)]) then
            love.graphics.print('VALID', 10, 20)
        else
            love.graphics.print('NOT VALID', 10, 20)
        end
    end
end

function love.draw()
	if startPosition ~= lastStartPosition or goalPosition ~= lastGoalPosition then
		--find(startPosition, goalPosition)
	end

    love.graphics.push()
    love.graphics.scale(scale, -scale)
    love.graphics.translate(xOffset, -yOffset)

    love.graphics.setColor( 0.2, 0.2, 0.2 )
    love.graphics.setLineWidth(0.2)
    love.graphics.line(-1000, 0, 1000, 0)
    love.graphics.line(0, -1000, 0, 1000)

    love.graphics.setColor( 0, 1, 0 )
    love.graphics.setPointSize(3)
    love.graphics.points(line)

    love.graphics.setColor(0.0, 0.8, 0.0)
    drawNode(startPosition)
    love.graphics.setColor(0.8, 0.0, 0.0)
    drawNode(goalPosition)
    love.graphics.setColor(0, 0.8, 0)

    love.graphics.setPointSize(5)

    drawPath(dubinsPath, 3, 0.8, 0.8, 0)
    drawPath(rsPath, 2, 0, 0.3, 0.8)

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

	love.graphics.setColor( 0.3, 0.3, 0.3 )
	love.graphics.line(10, courseLength + distanceToFieldEdge:get(), 30,
            courseLength + distanceToFieldEdge:get())

	for _, c in pairs(courses) do
		drawCourse(c.waypoints, workWidth:get(), 8, 0.5, 0.5, 0.5)
	end
	for _, c in pairs(turnCourses) do
		drawCourse(c.waypoints, 0.1, 4)
	end
	for _, c in pairs(turnContexts) do
		c:drawDebug()
	end

    love.graphics.pop()
    showStatus()
end

local function love2real( x, y )
    return ( x / scale ) - xOffset,  - ( y / scale ) + yOffset
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
    elseif key == 'p' then
        currentPathfinderIndex = (currentPathfinderIndex + 1) > #pathfinders and 1 or currentPathfinderIndex + 1
    end
    io.stdout:flush()
end

function love.textinput(key)
    for _, p in pairs(parameters) do
        p:onKey(key, function()
            return calculateTurn()
        end)
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
			calculateTurn()
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

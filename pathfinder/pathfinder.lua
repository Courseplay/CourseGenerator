g_Courseplay = {
    globalSettings = {
        getSettings = function()
            return {
                deltaAngleRelaxFactorDeg = {
                    getValue = function()
                        return 10
                    end
                },
                maxDeltaAngleAtGoalDeg = {
                    getValue = function()
                        return 45
                    end
                },
            }
        end
    }
}

function openIntervalTimer()
end

function readIntervalTimerMs(timer)
    return 0
end

function closeIntervalTimer(timer)
end

function printCallstack()
    print(debug.traceback())
end

require('HybridAStar')
require('AStar')
require('HybridAStarWithAStarInTheMiddle')
require('PathfinderUtil')
--[[
require('GraphPathfinder')

local GraphEdge = GraphPathfinder.GraphEdge
local graph = {
    GraphEdge(GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(100, 100),
                Vertex(110, 100),
                Vertex(120, 100)
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(100, 105),
                Vertex(110, 105),
                Vertex(120, 105),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(125, 130),
                Vertex(125, 120),
                Vertex(125, 105),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(130, 105),
                Vertex(130, 120),
                Vertex(130, 130),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(125, 95),
                Vertex(125, 80),
                Vertex(125, 70)
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(130, 70),
                Vertex(130, 80),
                Vertex(130, 95),
            }),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(135, 100),
                Vertex(160, 100),
                Vertex(185, 130),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(135, 135),
                Vertex(145, 135),
                Vertex(180, 135),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(180, 140),
                Vertex(145, 140),
                Vertex(135, 140),
            }),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(185, 140),
                Vertex(185, 170),
            }),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(95, 105),
                Vertex(95, 165),
            }),

    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(125, 160),
                Vertex(125, 150),
                Vertex(125, 140),
            }),
    GraphEdge(
            GraphEdge.UNIDIRECTIONAL,
            {
                Vertex(130, 140),
                Vertex(130, 150),
                Vertex(130, 160),
            }),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(130, 165),
                Vertex(150, 200),
            }
    ),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(95, 170),
                Vertex(145, 200),
            }
    ),
    GraphEdge(
            GraphEdge.BIDIRECTIONAL,
            {
                Vertex(185, 170),
                Vertex(155, 200),
            }
    ),
}
]]
function drawGraph()
--[[
    love.graphics.setPointSize(5)
    for _, e in ipairs(graph) do
        for i, v, _, next in e:vertices() do
            if next then
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.line(v.x, v.y, next.x, next.y)
            end
            if i == 1 then
                love.graphics.setColor(0.0, 0.4, 0.0)
                love.graphics.points(v.x, v.y)
            elseif i == #e then
                if e:isBidirectional() then
                    love.graphics.setColor(0.0, 0.4, 0.0)
                else
                    love.graphics.setColor(0.4, 0.0, 0.0)
                end
                love.graphics.points(v.x, v.y)
            end
        end
    end
]]
end

---@class TestConstraints : PathfinderConstraintInterface
local TestConstraints = CpObject(PathfinderConstraintInterface)
function TestConstraints:init()
    self.boxes = {
        Polygon({Vector(-40, 30), Vector(100, 30), Vector(100, 60), Vector(-30, 60)}),
        Polygon({Vector(-30, 70), Vector(100, 70), Vector(100, 100), Vector(-40, 100)})
    }
    self.penalty = 10
end

function TestConstraints:isValidNode(node)
    return true
end

function TestConstraints:isValidAnalyticSolutionNode(node)
    for _, b in ipairs(self.boxes) do
        if b:isInside(node.x, node.y) then
            return false
        end
    end
    return true
end

local nPenaltyCalls = 0

function TestConstraints:getNodePenalty(node)
    nPenaltyCalls = nPenaltyCalls + 1
    for _, b in ipairs(self.boxes) do
        if b:isInside(node.x, node.y) then
            return self.penalty
        end
    end
    return 0
end

local constraints = TestConstraints()
local pathfinder = HybridAStarWithAStarInTheMiddle({}, 20)
--local pathfinder = GraphPathfinder(20, 1000, 20, graph)
local path = nil

TestPathfinder = {}
function TestPathfinder.start(start, goal, turnRadius)
    nPenaltyCalls = 0
    local result = TestPathfinder.call(pathfinder.start, start, goal, turnRadius, false, constraints, 5)
    if result.done then
        TestPathfinder.onFinish(result)
    end
end

function TestPathfinder.update()
    if pathfinder:isActive() then
        --- Applies coroutine for path finding
        local result = TestPathfinder.call(pathfinder.resume)
        if result.done then
            TestPathfinder.onFinish(result)
        end
    end
end

function TestPathfinder.onFinish(result)
    local hasValidPath = result.path and #result.path >= 2
    if hasValidPath then
        path = result.path
        if pathfinder.nodes then
           -- pathfinder.nodes:print()
        end
    else
        path = nil
    end
end

function TestPathfinder.getPath()
    return path
end

function TestPathfinder.getPenaltyCalls()
    return nPenaltyCalls
end

---@return Polygon[]
function TestPathfinder.getProhibitedPolygons()
    return constraints.boxes
end

function TestPathfinder.setNodePenalty(penalty)
    constraints.penalty = penalty
end

function TestPathfinder.setHybridRange(range)
    pathfinder.hybridRange = range
end

function TestPathfinder.getNodeIteratorStart()
    return pathfinder and TestPathfinder.getNodeIterator(pathfinder.nodeIteratorStart)
end

function TestPathfinder.getNodeIteratorMiddle()
    return pathfinder and TestPathfinder.getNodeIterator(pathfinder.nodeIteratorMiddle)
end

function TestPathfinder.getNodeIteratorEnd()
    return pathfinder and TestPathfinder.getNodeIterator(pathfinder.nodeIteratorEnd)
end

------------------------------------------------------------------------------------------------------------------------
--- Hacks to make it work with AStar and HybridAStar too, not just the HybridAStarWithAStarInTheMiddle
------------------------------------------------------------------------------------------------------------------------
function TestPathfinder.getNodeIterator(iterator)
    return iterator and iterator(pathfinder) or pathfinder:nodeIterator()
end

function TestPathfinder.call(func, ...)
    local resultOrDone, resultPath = func(pathfinder, ...)
    if type(resultOrDone) ~= 'table' then
        return {done = resultOrDone, path = resultPath}
    else
        return resultOrDone
    end
end


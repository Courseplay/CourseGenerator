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

require('GraphSegment')
require('HybridAStar')
require('AStar')
require('HybridAStarWithAStarInTheMiddle')
require('PathfinderUtil')
require('GraphPathfinder')

local pathfinder = HybridAStarWithAStarInTheMiddle({}, 20)
local path = nil

local GraphEdge = GraphPathfinder.GraphEdge
local graph = {}

---@class TestConstraints : PathfinderConstraintInterface
local TestConstraints = CpObject(PathfinderConstraintInterface)
function TestConstraints:init()
    self.boxes = {
        Polygon({Vector(-400, 30), Vector(100, 30), Vector(100, 60), Vector(-430, 60)}),
        Polygon({Vector(-400, 70), Vector(100, 70), Vector(100, 100), Vector(-400, 100)}),
        Polygon({Vector(-400, 30), Vector(-400, 120), Vector(-370, 120), Vector(-370, 30)})
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

TestPathfinder = {}

function TestPathfinder.setGraph(loadedGraph)
    graph = loadedGraph or defaultGraph
    pathfinder = GraphPathfinder(2, 1000, 20, graph)
end

function TestPathfinder.start(start, goal, turnRadius)
    nPenaltyCalls = 0
    local result = pathfinder:start(start, goal, turnRadius, false, constraints, 5)
    if result.done then
        TestPathfinder.onFinish(result)
    end
end

function TestPathfinder.update()
    if pathfinder:isActive() then
        --- Applies coroutine for path finding
        local result = pathfinder:resume()
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
--- Hack to make it work with AStar and HybridAStar too, not just the HybridAStarWithAStarInTheMiddle
------------------------------------------------------------------------------------------------------------------------
function TestPathfinder.getNodeIterator(iterator)
    return iterator and iterator(pathfinder) or pathfinder:nodeIterator()
end

function TestPathfinder.drawGraph()
    if pathfinder.isa and pathfinder:isa(GraphPathfinder) then
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
    end
end

function TestPathfinder.drawProhibitedAreas()
    if pathfinder.isa and not pathfinder:isa(GraphPathfinder) then
        love.graphics.setColor(0.2, 0.2, 0.2)
        for _, p in ipairs(TestPathfinder.getProhibitedPolygons()) do
            love.graphics.polygon('line', p:getUnpackedVertices())
        end
    end
end


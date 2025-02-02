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

require('HybridAStar')

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

function TestConstraints:getNodePenalty(node)
    for _, b in ipairs(self.boxes) do
        if b:isInside(node.x, node.y) then
            return self.penalty
        end
    end
end

local constraints = TestConstraints()
local pathfinder = HybridAStarWithAStarInTheMiddle(20)
local pathfinder = AStar({})
local path = nil

TestPathfinder = {}
function TestPathfinder.start(start, goal, turnRadius)
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
    local hasValidPath = result.path and #result.path > 2
    if hasValidPath then
        path = result.path
        if pathfinder.nodes then pathfinder.nodes:print()

        end
    else
        path = nil
    end
end

function TestPathfinder.getPath()
    return path
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
    local resultOrOk, done, resultPath = func(pathfinder, ...)
    if type(resultOrOk) ~= 'table' then
        return {done = done, path = resultPath}
    else
        return resultOrOk
    end
end

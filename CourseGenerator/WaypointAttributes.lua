--- A container to hold waypoint and fieldwork related attributes
--- for a vertex.
--- These attributes contain information to help the vehicle navigate the course, while
--- the vertex is strictly a geometric concept.
local WaypointAttributes = CpObject()

function WaypointAttributes:init()
    self.islandBypass = false
    self.headlandTransition = false
    self.headlandPassNumber = nil
end

function WaypointAttributes:clone()
    local a = cg.WaypointAttributes()
    a.islandBypass = self.islandBypass
    a.headlandTransition = self.headlandTransition
    a.headlandPassNumber = self.headlandPassNumber
    return a
end

function WaypointAttributes:setIslandBypass(bypass)
    self.islandBypass = bypass
end

function WaypointAttributes:getIslandBypass()
    return self.islandBypass
end

function WaypointAttributes:setHeadlandTransition(transition)
    self.headlandTransition = transition
end

function WaypointAttributes:getHeadlandTransition()
    return self.headlandTransition
end

function WaypointAttributes:setHeadlandPassNumber(n)
    self.headlandPassNumber = n
end

---@return number | nil number of the headland, starting at 1 on the outermost headland. The section leading
--- to the next headland (getHeadlandTransition() == true) has the same pass number as the headland where the
--- section starts (transition from 1 -> 2 has pass number 1)
function WaypointAttributes:getHeadlandPassNumber()
    return self.headlandPassNumber
end

function WaypointAttributes:__tostring()
    local str = string.format('headlandPassNumber: %s, islandBypass: %s, headlandTransition %s',
            self.headlandPassNumber, self.islandBypass, self.headlandTransition)
    return str
end

---@class cg.WaypointAttributes
cg.WaypointAttributes = WaypointAttributes
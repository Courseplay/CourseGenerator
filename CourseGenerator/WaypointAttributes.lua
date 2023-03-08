--- A container to hold waypoint and fieldwork related attributes
--- for a vertex, to keep the vertex strictly geometric
local WaypointAttributes = CpObject()

function WaypointAttributes:init()
    self.islandBypass = false
    self.headlandTransition = false
end

function WaypointAttributes:clone()
    local a = cg.WaypointAttributes()
    a.islandBypass = self.islandBypass
    a.headlandTransition = self.headlandTransition
    return a
end

function WaypointAttributes:setIslandBypass(bypass)
    self.islandBypass = bypass
end

function WaypointAttributes:getIslandBypass()
    return self.islandBypass
end

function WaypointAttributes:setHeadlandTransition(bypass)
    self.headlandTransition = bypass
end

function WaypointAttributes:getHeadlandTransition()
    return self.headlandTransition
end

function WaypointAttributes:__tostring()
    local str = string.format('islandBypass: %s, headlandTransition %s',
            self.islandBypass, self.headlandTransition)
    return str
end

---@class cg.WaypointAttributes
cg.WaypointAttributes = WaypointAttributes
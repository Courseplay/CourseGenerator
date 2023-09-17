--- A container to hold waypoint and fieldwork related attributes
--- for a vertex.
--- These attributes contain information to help the vehicle navigate the course, while
--- the vertex is strictly a geometric concept.
local WaypointAttributes = CpObject()

function WaypointAttributes:clone()
    local a = cg.WaypointAttributes()
    for attribute, value in pairs(self) do
        a[attribute] = value
    end
    return a
end

function WaypointAttributes:setIslandBypass()
    self.islandBypass = true
end

---@return boolean true if the waypoint is part of a path bypassing a small island.
function WaypointAttributes:isIslandBypass()
    return self.islandBypass
end

function WaypointAttributes:setHeadlandTransition()
    self.headlandTransition = true
end

function WaypointAttributes:isHeadlandTransition()
    return self.headlandTransition
end

function WaypointAttributes:setHeadlandPassNumber(n)
    self.headlandPassNumber = n
end

---@return number | nil number of the headland, starting at 1 on the outermost headland. The section leading
--- to the next headland (isHeadlandTransition() == true) has the same pass number as the headland where the
--- section starts (transition from 1 -> 2 has pass number 1)
function WaypointAttributes:getHeadlandPassNumber()
    return self.headlandPassNumber
end

function WaypointAttributes:setBlockNumber(n)
    self.blockNumber = n
end

function WaypointAttributes:getBlockNumber()
    return self.blockNumber
end

function WaypointAttributes:setRowNumber(n)
    self.rowNumber = n
end

function WaypointAttributes:getRowNumber()
    return self.rowNumber
end

---@return boolean true if this is the last waypoint of an up/down row. It is either time to switch to the next
--- row (by starting a turn) of the same block, the first row of the next block, or, to the headland if we
--- started working on the center of the field
function WaypointAttributes:setRowEnd()
    self.rowEnd = true
end

function WaypointAttributes:isRowEnd()
    return self.rowEnd
end

function WaypointAttributes:setRowStart()
    self.rowStart = true
end

---@return boolean true if this is the first waypoint of an up/down row.
function WaypointAttributes:isRowStart()
    return self.rowStart
end

function WaypointAttributes:setIslandHeadland()
    self.islandHeadland = true
end

---@return boolean true if this waypoint is part of a headland around a (big) island. Small islands are bypassed
--- and there isIslandBypass is set to true.
function WaypointAttributes:isIslandHeadland()
    return self.islandHeadland
end

function WaypointAttributes:setUsePathfinderToNextWaypoint()
    self.usePathfinderToNextWaypoint = true
end

--- if this is true, the driver should use the pathfinder to navigate to the next waypoint. One example of this is
--- switching from an end of the row to an island headland.
function WaypointAttributes:shouldUsePathfinderToNextWaypoint()
    return self.usePathfinderToNextWaypoint
end

function WaypointAttributes:setOnConnectingPath()
    self.isOnConnectingPath = true
end

--- Is this waypoint on a connecting path, that is, a section connecting the headlands to the
--- first waypoint of the up/down rows (or vica versa), or a section connecting two blocks?y
--- In general, the driver should lift their implements and follow this path, maybe removing the
--- first and the last waypoint of it to make room to maneuver, and use the pathfinder when transitioning
--- to or from this section. For instance, if this path leads to the first up/down row, the generator
--- cannot guarantee that there are no obstacles (like a small island) between the last waypoint
--- of this path and the first up/down waypoint.
function WaypointAttributes:isOnConnectingPath()
    return self.isOnConnectingPath
end

---@param headland cg.Headland
function WaypointAttributes:_setAtHeadland(headland)
    self.atHeadland = headland
end

--- For generator internal use only, this is set for row end and start waypoints, storing the Headland object
--- terminating the row
---@return cg.Headland
function WaypointAttributes:_getAtHeadland()
    return self.atHeadland
end

--- For generator internal use only, this is set for row end and start waypoints, storing the Island object
--- terminating the row
---@return cg.Island|nil
function WaypointAttributes:_getAtIsland()
    return self.atHeadland and self.atHeadland:isIslandHeadland() and self.atHeadland:getIsland()
end

function WaypointAttributes:__tostring()
    local str = '[ '
    for attribute, value in pairs(self) do
        str = str .. string.format('%s: %s ', attribute, value)
    end
    str = str .. ']'
    return str
end

---@class cg.WaypointAttributes
cg.WaypointAttributes = WaypointAttributes
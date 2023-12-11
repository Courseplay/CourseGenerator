--- An up/down row (swath) in the middle of the field (the area surrounded by the field boundary or the
--- innermost headland).
---@class Row : Polyline
local Row = CpObject(cg.Polyline)

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Row:init(workingWidth, vertices)
    cg.Polyline.init(self, vertices)
    self.workingWidth = workingWidth
    self.logger = Logger('Row ' .. tostring(self.rowNumber), Logger.level.debug)
end

function Row:setRowNumber(n)
    self.rowNumber = n
end

function Row:setBlockNumber(n)
    self.blockNumber = n
end

--- Sequence number to keep the original row sequence for debug purposes
function Row:setOriginalSequenceNumber(n)
    self.sequenceNumber = n
end

function Row:getOriginalSequenceNumber()
    return self.sequenceNumber
end

function Row:clone()
    local clone = cg.Row(self.workingWidth)
    for _, v in ipairs(self) do
        clone:append(v:clone())
    end
    clone:calculateProperties()
    clone.blockNumber = self.blockNumber
    clone.sequenceNumber = self.sequenceNumber
    clone.startHeadlandAngle, clone.endHeadlandAngle = self.startHeadlandAngle, self.endHeadlandAngle
    clone.startsAtHeadland, clone.endsAtHeadland = self.startsAtHeadland, self.endsAtHeadland
    return clone
end

--- Create a row parallel to this one at offset distance.
---@param offset number distance of the new row. New row will be on the left side
--- (looking at increasing vertex indices) when offset > 0, right side otherwise.
function Row:createNext(offset)
    if offset >= 0 then
        return cg.Offset.generate(self, cg.Vector(0, 1), offset)
    else
        return cg.Offset.generate(self, cg.Vector(0, -1), -offset)
    end
end

--- Override Polyline:createOffset() to make sure the offset is an instance of Row
function Row:createOffset(offsetVector, minEdgeLength, preserveCorners)
    local offsetRow = cg.Row(self.workingWidth)
    return self:_createOffset(offsetRow, offsetVector, minEdgeLength, preserveCorners)
end

--- Does the other row overlap this one?
---@param other cg.Row
---@return boolean
function Row:overlaps(other)
    -- for simplicity, use a simple line segment instead of a polyline, rows are
    -- more or less straight anyway
    local myEndToEnd = cg.LineSegment.fromVectors(self[1], self[#self])
    local otherEndToEnd = cg.LineSegment.fromVectors(other[1], other[#other])
    return myEndToEnd:overlaps(otherEndToEnd)
end

--- Split a row at its intersections with the field boundary and with big islands.
--- In the trivial case of a rectangular field, this returns an array with a single row element,
--- the line between the two points where the row intersects the boundary.
---
--- In complex cases, with concave fields, the result may be more than one segments (rows)
--- so for any section of the row which is within the boundary there'll be one entry in the
--- returned array.
---
--- Big islands in the field also split a row which intersects them. We just drive around
--- smaller islands but at bigger ones it is better to end the row and turn around into the next.
---
---@param headland cg.Headland the field boundary (or innermost headland)
---@param bigIslands cg.Island[] islands big enough to split a row (we'll not just drive around them but turn)
---@param onlyFirstAndLastIntersections|nil boolean ignore all intersections between the first and the last. This makes
--- only sense if there are no islands. For cases where the row is almost parallel to the boundary and crosses it
--- multiple times, so we rather not split it
---@return cg.Row[]
function Row:split(headland, bigIslands, onlyFirstAndLastIntersections)
    -- get all the intersections with the field boundary
    local intersections = self:getIntersections(headland:getPolygon(), 1,
            {
                isEnteringField = function(is)
                    -- when entering a field boundary polygon, we move on to the field
                    -- use the requested chirality of the headland as it may have loops in there which
                    -- will fool the isEntering functions
                    return self:isEntering(headland:getPolygon(), is, headland:getRequestedClockwise())
                end,
                headland = headland
            }
    )

    if #intersections < 2 then
        self.logger:warning('Row has only %d intersection with headland %d', #intersections, headland:getPassNumber())
        return {}
    end

    if onlyFirstAndLastIntersections then
        intersections[2] = intersections[#intersections]
        for _ = 3, #intersections do
            table.remove(intersections)
        end
    end

    -- then get all the intersections with big islands
    for _, island in ipairs(bigIslands) do
        local outermostIslandHeadland = island:getOutermostHeadland()
        local islandIntersections = self:getIntersections(outermostIslandHeadland:getPolygon(), 1,
                {
                    isEnteringField = function(is)
                        -- when entering an island headland, we move off the field
                        return not self:isEntering(outermostIslandHeadland:getPolygon(), is)
                    end,
                    headland = outermostIslandHeadland
                }
        )

        self.logger:trace('Row has %d intersections with island %d', #islandIntersections, island:getId())
        for _, is in ipairs(islandIntersections) do
            table.insert(intersections, is)
        end
        table.sort(intersections)
    end
    -- At this point, intersections contains all intersections of the row with the field boundary and any big islands,
    -- in the order the row crosses them.

    -- The assumption here is that the row always begins outside of the boundary. So whenever we cross a field boundary
    -- entering, we are on the field, whenever cross an island headland, we move off the field.

    -- This is also to properly handle the cases where the boundary intersects with
    -- itself, for instance with fields where the total width of headlands are greater than the
    -- field width (irregularly shaped fields, like ones with a peninsula)
    -- we start outside of the boundary. If we cross it entering, we'll decrement this, if we cross leaving, we'll increment it.
    local outside = 1
    local lastInsideIx
    local sections = {}
    for i = 1, #intersections do
        -- getUserData() depends on if this is a field boundary or an island
        local isEnteringField = intersections[i]:getUserData().isEnteringField(intersections[i])
        -- For the case when the row begins on a big island and the headland is bypassing that big island,
        -- meaning that there will be two intersections, at the exact same position, one with the island,
        -- and another with the headland, we'd enter the field twice (outside == -1). Don't let the inside
        -- counter go below 0 here
        outside = math.max(0, outside + (isEnteringField and -1 or 1))
        if not isEnteringField and outside == 1 then
            -- exiting the polygon and we were inside before (outside was 0)
            -- create a section here
            local section = self:_cutAtIntersections(intersections[lastInsideIx], intersections[i])
            -- remember the angle we met the headland so we can adjust the length of the row to have 100% coverage
            -- skip very short rows, if it is shorter than the working width then the area will
            -- be covered anyway by the headland passes
            if section:getLength() < self.workingWidth then
                self.logger:trace('ROW TOO SHORT %.1f, %s', section:getLength(), intersections[i])
            else
                section.startHeadlandAngle = intersections[lastInsideIx]:getAngle()
                -- remember at what headland the row ends
                section.startsAtHeadland = intersections[lastInsideIx]:getUserData().headland
                section.endHeadlandAngle = intersections[i]:getAngle()
                section.endsAtHeadland = intersections[i]:getUserData().headland
                section:setEndAttributes()
                table.insert(sections, section)
            end
        elseif isEnteringField then
            lastInsideIx = i
        end
    end
    return sections
end

--- Get the coordinates in the middle of the row, for instance to display the row number. Assumes
--- that the vertices are approximately evenly distributed
---@return cg.Vector coordinates of the middle of the row
function Row:getMiddle()
    if #self % 2 == 0 then
        -- even number of vertices, return a point between the middle two
        local left = self[#self / 2]
        local right = self[#self / 2 + 1]
        return (left + right) / 2
    else
        -- odd number of vertices, return the middle one
        return self[math.floor(#self / 2)]
    end
end

--- What is on the left and right side of the row?
function Row:setAdjacentRowInfo(rowOnLeftWorked, rowOnRightWorked, leftSideBlockBoundary, rightSideBlockBoundary)
    self.rowOnLeftWorked = rowOnLeftWorked
    self.rowOnRightWorked = rowOnRightWorked
    self.leftSideBlockBoundary = leftSideBlockBoundary
    self.rightSideBlockBoundary = rightSideBlockBoundary
end

--- Update the attributes of the first and last vertex of the row based on the row's properties.
--- We use these attributes when finding an entry to a block, to see if the entry is on an island headland
--- or not. The attributes are set when the row is split at headlands but may need to be reapplied when
--- we adjust the end of the row as we may remove the first/last vertex.
function Row:setEndAttributes()
    self:setAttribute(1, cg.WaypointAttributes.setRowStart)
    self:setAttribute(1, cg.WaypointAttributes._setAtHeadland, self.startsAtHeadland)
    self:setAttribute(1, cg.WaypointAttributes.setAtBoundaryId, self.startsAtHeadland:getBoundaryId())
    self:setAttribute(#self, cg.WaypointAttributes.setRowEnd)
    self:setAttribute(#self, cg.WaypointAttributes._setAtHeadland, self.endsAtHeadland)
    self:setAttribute(#self, cg.WaypointAttributes.setAtBoundaryId, self.endsAtHeadland:getBoundaryId())
end

function Row:setAllAttributes()
    self:setEndAttributes()
    self:setAttribute(nil, cg.WaypointAttributes.setRowNumber, self.rowNumber)
    self:setAttribute(nil, cg.WaypointAttributes.setBlockNumber, self.blockNumber)
    self:setAttribute(nil, cg.WaypointAttributes.setLeftSideWorked, self.rowOnLeftWorked)
    self:setAttribute(nil, cg.WaypointAttributes.setRightSideWorked, self.rowOnRightWorked)
    self:setAttribute(nil, cg.WaypointAttributes.setLeftSideBlockBoundary, self.leftSideBlockBoundary)
    self:setAttribute(nil, cg.WaypointAttributes.setRightSideBlockBoundary, self.rightSideBlockBoundary)
end

function Row:reverse()
    cg.Polyline.reverse(self)
    self.startHeadlandAngle, self.endHeadlandAngle = self.endHeadlandAngle, self.startHeadlandAngle
    self.startsAtHeadland, self.endsAtHeadland = self.endsAtHeadland, self.startsAtHeadland
    self.rowOnLeftWorked, self.rowOnRightWorked = self.rowOnRightWorked, self.rowOnLeftWorked
    self.leftSideBlockBoundary, self.rightSideBlockBoundary = self.rightSideBlockBoundary, self.leftSideBlockBoundary
end

--- Adjust the length of this tow for full coverage where it meets the headland or field boundary
--- The adjustment depends on the angle the row meets the boundary/headland. In case of a headland,
--- and an angle of 90 degrees, we don't have to drive all the way up to the headland centerline, only
--- half workwidth.
--- In case of a field boundary we have to drive up all the way to the boundary.
--- The value obviously depends on the angle.
function Row:adjustLength()
    cg.FieldworkCourseHelper.adjustLengthAtStart(self, self.workingWidth, self.startHeadlandAngle)
    cg.FieldworkCourseHelper.adjustLengthAtEnd(self, self.workingWidth, self.endHeadlandAngle)
end

--- Find the first two intersections with another polyline or polygon and replace the section
--- between those points with the vertices of the other polyline or polygon.
---@param other Polyline
---@param startIx number index of the vertex we want to start looking for intersections.
---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
---@return boolean, number true if there was an intersection and we actually went around, index of last vertex
--- after the bypass
function Row:bypassSmallIsland(other, startIx, circle)
    cg.FieldworkCourseHelper.bypassSmallIsland(self, self.workingWidth, other, startIx, circle)
end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------

------ Cut a polyline at is1 and is2, keeping the section between the two. is1 and is2 becomes the start and
--- end of the cut polyline.
---@param is1 cg.Intersection
---@param is2 cg.Intersection
---@return cg.Row
function Row:_cutAtIntersections(is1, is2)
    local section = cg.Row(self.workingWidth)
    section:append(is1.is)
    local src = is1.ixA + 1
    while src < is2.ixA do
        section:append(self[src])
        src = src + 1
    end
    section:append(is2.is)
    section:calculateProperties()
    return section
end

---@class cg.Row
cg.Row = Row
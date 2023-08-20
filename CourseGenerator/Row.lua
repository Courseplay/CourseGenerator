--- An up/down row (swath) in the middle of the field (the area surrounded by the field boundary or the
--- innermost headland).
---@class Row : Polyline
local Row = CpObject(cg.Polyline)

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Row:init(workingWidth, vertices)
    cg.Polyline.init(self, vertices)
    self.workingWidth = workingWidth
    self.logger = cg.Logger('Row', cg.Logger.level.debug)
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

--- Split a row at its intersections with boundary. In the trivial case of a rectangular field,
--- this returns an array with a single polyline element, the line between the two points where
--- the row intersects the boundary.
---
--- In complex cases, with concave fields, the result may be more than one segments (polylines)
--- so for any section of the row which is within the boundary there'll be one entry in the
--- returned array.
---
---@param boundary cg.Polygon the field boundary (or innermost headland)
---@param boundaryIsHeadland boolean true if the boundary is a headland
---@return cg.Row[]
function Row:split(boundary, boundaryIsHeadland)
    local intersections = self:getIntersections(boundary, 1)
    if #intersections < 2 then
        self.logger:warning('Row has only %d intersection with boundary', #intersections)
        return cg.Row(self.workingWidth)
    end
    -- The assumption here is that the row always begins outside of the boundary
    -- This latter condition is to properly handle the cases where the boundary intersects with
    -- itself, for instance with fields where the total width of headlands are greater than the
    -- field width (irregularly shaped fields, like ones with a peninsula)
    -- we start outside of the boundary. If we cross it entering, we'll decrement this, if we cross leaving, we'll increment it.
    local outside = 1
    local lastInsideIx
    local sections = {}
    for i = 1, #intersections do
        local isEntering = self:isEntering(boundary, intersections[i])
        outside = outside + (isEntering and -1 or 1)
        if not isEntering and outside == 1 then
            -- exiting the polygon and we were inside before (outside was 0)
            -- create a section here
            local section = self:_cutAtIntersections(intersections[lastInsideIx], intersections[i])
            section.startHeadlandAngle = intersections[lastInsideIx]:getAngle()
            section.endHeadlandAngle = intersections[i]:getAngle()
            section.boundaryIsHeadland = boundaryIsHeadland
            table.insert(sections, section)
        elseif isEntering then
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

function Row:setRowNumber(n)
    self.rowNumber = n
end

function Row:setBlockNumber(n)
    self.blockNumber = n
end

--- Sequence number to keep the original row sequence for debug purposes
function Row:setSequenceNumber(n)
    self.sequenceNumber = n
end

function Row:getSequenceNumber()
    return self.sequenceNumber
end

function Row:setAllAttributes()
    self:setAttributes(1, 1, cg.WaypointAttributes.setRowStart)
    self:setAttributes(#self, #self, cg.WaypointAttributes.setRowEnd)
    self:setAttributes(nil, nil, cg.WaypointAttributes.setRowNumber, self.rowNumber)
    self:setAttributes(nil, nil, cg.WaypointAttributes.setBlockNumber, self.blockNumber)
end

function Row:reverse()
    cg.Polyline.reverse(self)
    self.startHeadlandAngle, self.endHeadlandAngle = self.endHeadlandAngle, self.startHeadlandAngle
end

--- Adjust the length of this tow for full coverage where it meets the headland or field boundary
--- The adjustment depends on the angle the row meets the boundary/headland. In case of a headland,
--- and an angle of 90 degrees, we don't have to drive all the way up to the headland centerline, only
--- half workwidth.
--- In case of a field boundary we have to drive up all the way to the boundary.
--- The value obviously depends on the angle.
function Row:adjustLength()
    cg.FieldworkCourseHelper.adjustLengthAtStart(self, self.workingWidth, self.boundaryIsHeadland, self.startHeadlandAngle)
    cg.FieldworkCourseHelper.adjustLengthAtEnd(self, self.workingWidth, self.boundaryIsHeadland, self.endHeadlandAngle)
end

--- Find the first two intersections with another polyline or polygon and replace the section
--- between those points with the vertices of the other polyline or polygon.
---@param other Polyline
---@param startIx number index of the vertex we want to start looking for intersections.
---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
---@return boolean, number true if there was an intersection and we actually went around, index of last vertex
--- after the bypass
function Row:bypassIsland(other, startIx, circle)
    cg.FieldworkCourseHelper.bypassIsland(self, self.workingWidth, self.boundaryIsHeadland, other, startIx, circle)
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
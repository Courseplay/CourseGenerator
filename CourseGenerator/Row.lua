--- An up/down row (swath) in the middle of the field (the area surrounded by the field boundary or the
--- innermost headland).
local Row = CpObject(cg.Polyline)

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Row:init(vertices)
    self.logger = cg.Logger('Row', cg.Logger.level.debug)
    cg.Polyline.init(self, vertices)
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
    local offsetRow = cg.Row()
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
---@return cg.Row[]
function Row:split(boundary)
    local intersections = self:getIntersections(boundary, 1)
    if #intersections < 2 then
        self.logger:warning('Row has only %d intersection with boundary', #intersections)
        return cg.Row()
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
            table.insert(sections, self:_cutAtIntersections(intersections[lastInsideIx], intersections[i]))
        elseif isEntering then
            lastInsideIx = i
        end
    end
    return sections
end

--- Get the coordinates in the middle of the row, for instance to display the row number.
---@return cg.Vector coordinates of the middle of the row
function Row:getMiddle()
    if #self % 2 == 0 then
        -- even number of vertices, return a point between the middle two
        local left = self[#self / 2]
        local right = self[#self / 2 + 1]
        return (left + right) / 2
    else
        -- odd number of vertices, return the middle one\
        return self[math.floor(#self / 2)]
    end
end

--- Sequence number to keep the original row sequence for debug purposes
function Row:setSequenceNumber(n)
    self.sequenceNumber = n
end

function Row:getSequenceNumber()
    return self.sequenceNumber
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
    local section = cg.Row()
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
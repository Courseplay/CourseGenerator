local Polygon = CpObject(cg.Polyline)

--- Returns the vertex at position n. Will wrap around the ends, that is, will return
--- a valid vertex for -#self < n < 2 * #self.
function Polygon:at(n)
    -- whoever came up with the idea of 1 based indexing in lua, was terribly wrong,
    -- so for now we just wrap around once so we don't need to divide
    if n > #self then
        return self[n - #self]
    elseif n < 1 then
        return self[n + #self]
    else
        return self[n]
    end
end

--- edge iterator, will wrap through the end to close the polygon
---@return number, cg.LineSegment
function Polygon:edges()
    local i = 1
    return function()
        i = i + 1
        if i > #self + 1 then
            return nil, nil
        else
            return i - 1, cg.LineSegment.fromVectors(self[i - 1], self[i > #self and 1 or i])
        end
    end
end

function Polygon:isClockwise()
    if not self.deltaAngle then
        self:calculateProperties()
    end
    return self.deltaAngle > 0
end

function Polygon:ensureMinimumEdgeLength(minimumLength)
    cg.Polyline.ensureMinimumEdgeLength(self, minimumLength)
    if (self[1] - self[#self]):length() < minimumLength then
        table.remove(self, #self)
    end
end

--- Generate a polygon parallel to this one, offset by the offsetVector.
---@param offsetVector cg.Vector offset to move the edges, relative to the edge's direction
---@param minEdgeLength number see LineSegment.connect()
---@param preserveCorners number see LineSegment.connect()
function Polygon:createOffset(offsetVector, minEdgeLength, preserveCorners)
    local offsetEdges = self:generateOffsetEdges(offsetVector)
    local cleanOffsetEdges = self:cleanEdges(offsetEdges, minEdgeLength, preserveCorners)
    -- So far, same as the polyline, but now we need to take care of the connection between the
    -- last and the first edge.
    local gapFiller = cg.LineSegment.connect(cleanOffsetEdges[#cleanOffsetEdges], cleanOffsetEdges[1],
            minEdgeLength, preserveCorners)
    if gapFiller then
        table.insert(cleanOffsetEdges, gapFiller)
    end
    local offsetPolygon = cg.Polygon()
    for _, e in ipairs(cleanOffsetEdges) do
        offsetPolygon:append(e:getBase())
    end
    -- contrary to the polyline, no need to append the end of the last edge here as it is the same
    -- as the start of the first edge
    return offsetPolygon
end

---@class cg.Polygon:cg.Polyline
cg.Polygon = Polygon
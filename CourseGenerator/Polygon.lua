local Polygon = CpObject(cg.Polyline)

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

---
---
--- Generate a polyline parallel to this one, offset by the offsetVector
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
    local offsetPolyline = cg.Polyline()
    for _, e in ipairs(cleanOffsetEdges) do
        offsetPolyline:append(e:getBase())
    end
    -- contrary to the polyline, no need to append the end of the last edge here as it is the same
    -- as the start of the first edge
    return offsetPolyline
end

---@class cg.Polygon:cg.Polyline
cg.Polygon = Polygon
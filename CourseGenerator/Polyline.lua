local Polyline = CpObject()

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:init(vertices)
    if vertices then
        for i, v in ipairs(vertices) do
            self[i] = cg.Vertex(v.x, v.y, i)
        end
    end
    self.logger = cg.Logger('Polyline', cg.Logger.level.trace)
    self:calculateProperties()
end

---@param v table table with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:append(v)
    table.insert(self, cg.Vertex(v.x, v.y, #self + 1))
end

function Polyline:clone()
    local clone = Polyline({})
    for _, v in ipairs(self) do
        clone:append(v:clone())
    end
    clone:calculateProperties()
    return clone
end

function Polyline:getRawIndex(n)
    return n
end

--- Returns the vertex at position n. In the derived polygon, will wrap around the ends, that is, will return
--- a valid vertex for -#self < n < 2 * #self.
function Polyline:at(n)
    return self[self:getRawIndex(n)]
end

--- Sets the vertex at position n. In the derived polygon, will wrap around the ends, that is, will return
--- a valid vertex for -#self < n < 2 * #self.
function Polyline:set(n, v)
    self[self:getRawIndex(n)] = v
end

--- Upper limit when iterating through the vertices, starting with 1 to fwdIterationLimit() (inclusive)
--- using i and i + 1 vertex in the loop. This will not wrap around the end.
function Polyline:fwdIterationLimit()
    return #self - 1
end

--- Get the center of the polyline (centroid, average of all vertices)
function Polyline:getCenter()
    local center = cg.Vector(0, 0)
    for _, v in ipairs(self) do
        center = center + v
    end
    return center / #self
end

--- Get the bounding box
function Polyline:getBoundingBox()
    local xMin, xMax, yMin, yMax = math.huge, -math.huge, math.huge, -math.huge
    for _, v in ipairs(self) do
        xMin = math.min(xMin, v.x)
        yMin = math.min(yMin, v.y)
        xMax = math.max(xMax, v.x)
        yMax = math.max(yMax, v.y)
    end
    return xMin, yMin, xMax, yMax
end

function Polyline:calculateEdges()
    local edges = {}
    for _, e in self:edges() do
        table.insert(edges, e)
    end
    return edges
end

function Polyline:getUnpackedVertices()
    local unpackedVertices = {}
    for _, v in ipairs(self) do
        table.insert(unpackedVertices, v.x)
        table.insert(unpackedVertices, v.y)
    end
    return unpackedVertices
end

--- vertex iterator
function Polyline:vertices()
    local i = 0
    return function()
        i = i + 1
        if i > #self then
            return nil, nil
        else
            return i, self[i]
        end
    end
end

--- edge iterator
---@return number, cg.LineSegment
function Polyline:edges()
    local i = 1
    return function()
        i = i + 1
        if i > #self then
            return nil, nil
        else
            return i, cg.LineSegment.fromVectors(self[i - 1], self[i])
        end
    end
end

--- Get the length of the shortest edge (distance between vertices)
---@return number
function Polyline:getShortestEdgeLength()
    local shortest = math.huge
    for _, e in self:edges() do
        shortest = math.min(shortest, e:getLength())
    end
    return shortest
end

function Polyline:reverse()
    for i = 1, #self / 2 do
        self[i], self[#self - i + 1] = self[#self - i + 1], self[i]
    end
    self:calculateProperties()
end

--- Calculate all interesting properties we may need later for more advanced functions
---@param from number index of vertex to start the calculation, default 1
---@param to number index of last vertex to use in the calculation, default #self
function Polyline:calculateProperties(from, to)
    for i = from or 1, to or #self do
        self:at(i).ix = i
        self:at(i):calculateProperties(self:at(i - 1), self:at(i + 1))
    end
end

--- If two vertices are closer than minimumLength, replace them with one between.
function Polyline:ensureMinimumEdgeLength(minimumLength)
    local i = 1
    while i < #self do
        if (self:at(i + 1) - self:at(i)):length() < minimumLength then
            table.remove(self, i + 1)
        else
            i = i + 1
        end
    end
end

--- If two vertices are further than maximumLength apart, add a vertex between them. If the
--- delta angle at the first vertex is less than maxDeltaAngleForOffset, also offset the new vertex
--- to the left/right from the edge in an effort trying to follow a curve.
function Polyline:ensureMaximumEdgeLength(maximumLength, maxDeltaAngleForOffset)
    local i = 1
    while i <= self:fwdIterationLimit() do
        local exitEdge = cg.LineSegment.fromVectors(self:at(i), self:at(i + 1))
        if exitEdge:getLength() > maximumLength then
            if math.abs(self:at(i).dA) < maxDeltaAngleForOffset then
                -- for higher angles, like corners, we don't want to round them out here.
                exitEdge:setHeading(exitEdge:getHeading() - self:at(i).dA / 2)
            end
            exitEdge:setLength(exitEdge:getLength() / 2)
            local v = exitEdge:getEnd()
            table.insert(self, i + 1, cg.Vertex(v.x, v.y, i + 1))
            self:calculateProperties(i, i + 2)
            self.logger:trace('ensureMaximumEdgeLength: added a vertex after %d', i)
            i = i + 2
        else
            i = i + 1
        end
    end
end

---@param offsetVector cg.Vector offset to move the edges, relative to the edge's direction
---@return cg.LineSegment[] an array of edges parallel to the existing ones, same length
--- but offset by offsetVector
function Polyline:generateOffsetEdges(offsetVector)
    local offsetEdges = {}
    for _, e in self:edges() do
        local newOffsetEdge = e:clone()
        newOffsetEdge:offset(offsetVector.x, offsetVector.y)
        table.insert(offsetEdges, newOffsetEdge)
    end
    return offsetEdges
end

--- Make sure the edges are properly connected, their ends touch nicely without gaps and never
--- extend beyond the vertex
---@param edges cg.LineSegment[]
function Polyline:cleanEdges(edges, minEdgeLength, preserveCorners)
    local cleanEdges = { edges[1] }
    for i = 2, #edges do
        local previousEdge = cleanEdges[#cleanEdges]
        local currentEdge = edges[i]
        local gapFiller = cg.LineSegment.connect(previousEdge, currentEdge, minEdgeLength, preserveCorners)
        if gapFiller then
            table.insert(cleanEdges, gapFiller)
        end
        table.insert(cleanEdges, currentEdge)
        previousEdge = currentEdge
    end
    return cleanEdges
end

--- Generate a polyline parallel to this one, offset by the offsetVector
---@param offsetVector cg.Vector offset to move the edges, relative to the edge's direction
---@param minEdgeLength number see LineSegment.connect()
---@param preserveCorners number see LineSegment.connect()
function Polyline:createOffset(offsetVector, minEdgeLength, preserveCorners)
    local offsetEdges = self:generateOffsetEdges(offsetVector)
    local cleanOffsetEdges = self:cleanEdges(offsetEdges, minEdgeLength, preserveCorners)
    local offsetPolyline = cg.Polyline()
    for _, e in ipairs(cleanOffsetEdges) do
        offsetPolyline:append(e:getBase())
    end
    offsetPolyline:append(cleanOffsetEdges[#cleanOffsetEdges]:getEnd())
    return offsetPolyline
end

--- Ensure there are no sudden direction changes in the polyline, that is, at each vertex a vehicle
--- with turning radius r would be able to follow the line with less than cMaxCrossTrackError distance
--- from the corner vertex.
--- When such a corner is found, either make it rounder according to r, or make it sharp and mark it
--- as a turn waypoint.
---@param r number turning radius
---@param makeCorners boolean if true, make corners for turn maneuvers instead of rounding them.
function Polyline:ensureMinimumRadius(r, makeCorners)

    ---@param entry cg.Slider
    ---@param exit cg.Slider
    local function makeArc(entry, exit)
        local dubinsSolver = DubinsSolver()
        local from = entry:getBaseAsState3D()
        local to = exit:getBaseAsState3D()
        local solution = dubinsSolver:solve(from, to, r, true)
        return solution:getWaypoints(from, r)
    end

    ---@param entry cg.Slider
    ---@param exit cg.Slider
    local function makeCorner(entry, exit)
        entry:extendTo(exit)
        local corner = entry:getEnd()
        corner.color = { 0, 1, 0 }
        return { corner }
    end

    local wrappedAround = false
    local currentIx
    local nextIx = 1
    repeat
        currentIx = nextIx
        nextIx = currentIx + 1
        local xte = self:at(currentIx):getXte(r)
        if xte > cg.cMaxCrossTrackError then
            self.logger:debug('ensureMinimumRadius: found a corner at %d, r: %.1f', currentIx, r)
            -- looks like we can't make this turn without deviating too much from the course,
            local entry = cg.Slider(self, currentIx, 0)
            local exit = cg.Slider(self, currentIx, 0)
            local rMin
            repeat
                -- from the corner, start widening the gap until we can fit an
                -- arc with r between
                entry:move(-0.2)
                exit:move(0.2)
                rMin = entry:getRadiusTo(exit)
                --print('    -> ', entry.ix, exit.ix, rMin)
            until rMin >= r
            -- entry and exit are now far enough, so use the Dubins solver to effortlessly create a nice
            -- arc between the two, or, to make it a sharp corner, find the intersection of entry and exit
            local adjustedCornerVertices
            if makeCorners then
                adjustedCornerVertices = makeCorner(entry, exit)
            else
                adjustedCornerVertices = makeArc(entry, exit)
            end
            if adjustedCornerVertices and #adjustedCornerVertices >= 1 then
                -- replace the section with an arc or a corner
                nextIx, wrappedAround = self:replace(entry.ix, exit.ix, adjustedCornerVertices)
                self.logger:debug('ensureMinimumRadius: replaced corner from %d to %d with %d waypoint(s), continue at %d (of %d), wrapped around %s',
                        entry.ix, exit.ix, #adjustedCornerVertices, nextIx, #self, wrappedAround)
                self:calculateProperties(entry.ix, nextIx)
            else
                self.logger:debug('ensureMinimumRadius: could not calculate adjusted corner vertices')
            end
        end
    until wrappedAround or currentIx >= #self

    self:ensureMinimumEdgeLength(cg.cMinEdgeLength)
    if makeCorners then
        self:ensureMaximumEdgeLength(cg.cMaxEdgeLength, cg.cMaxDeltaAngleForMaxEdgeLength)
    end
    self:calculateProperties()
end

--- Find the first two intersections with another polyline or polygon and replace the section
--- between those points with the vertices of the other polyline or polygon.
---@param other Polyline
---@param startIx number index of the vertex we want to start looking for intersections.
function Polyline:goAround(other, startIx)
    local intersections = self:getIntersections(other, 2)
end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function Polyline:getIntersections(other, maxIntersections)

end

--- Replace all vertices from fromIx to toIx (including) with the entries in vertices
---@param fromIx number index of first vertex to replace
---@param toIx number index of last vertex to replace
---@param vertices cg.Vector[] new vertices to put between fromIx and toIx
---@return number, boolean index of the next vertex after the replaced ones (may be more or less than toIx depending on
--- how many entries vertices had and how many elements were there originally between fromIx and toIx. The boolean
--- is true when wrapped around the end (for a polygon)
function Polyline:replace(fromIx, toIx, vertices)
    -- mark the ones we need to replace/remove. this is to make the rollover case (for polygons) easier
    for i = fromIx, toIx do
        self[self:getRawIndex(i)].toBeReplaced = true
    end

    local sourceIx = 1
    local destIx = cg.WrapAroundIndex(self, fromIx)
    while self[destIx:get()] and self[destIx:get()].toBeReplaced do
        if sourceIx <= #vertices then
            local newVertex = cg.Vertex(vertices[sourceIx].x, vertices[sourceIx].y, destIx:get())
            newVertex.color = { 0, 1, 0 } -- for debug only
            self[destIx:get()] = newVertex
            self.logger:trace('Replaced %d', destIx:get())
            destIx = destIx + 1
        else
            table.remove(self, destIx:get())
            self.logger:trace('Removed %d', destIx:get())
        end
        sourceIx = sourceIx + 1
    end
    while sourceIx <= #vertices do
        -- we have some vertices left, but there is no room for them
        local newVertex = cg.Vertex(vertices[sourceIx].x, vertices[sourceIx].y, destIx:get())
        newVertex.color = { 1, 0, 0 } -- for debug only
        table.insert(self, destIx:get(), newVertex)
        self.logger:trace('Adding at %d', destIx:get())
        sourceIx = sourceIx + 1
        destIx = destIx + 1
    end
    return destIx:get(), destIx:get() < fromIx
end

function Polyline:__tostring()
    local result = ''
    for i, v in ipairs(self) do
        result = result .. string.format('%d %s\n', i, v)
    end
    return result
end

---@class cg.Polyline
cg.Polyline = Polyline
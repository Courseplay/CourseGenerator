local Polyline = CpObject()

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:init(vertices)
    if vertices then
        for i, v in ipairs(vertices) do
            self[i] = cg.Vertex(v.x, v.y, i)
        end
    end
    self.logger = cg.Logger('Polyline', cg.Logger.level.debug)
    self:calculateProperties()
end

---@param v table table with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:append(v)
    if v:is_a(cg.Vertex) then
        table.insert(self, v:clone())
        v.ix = #self
    else
        table.insert(self, cg.Vertex(v.x, v.y, #self + 1))
    end
end

---@param p cg.Vertex[]
function Polyline:appendMany(p)
    for _, v in ipairs(p) do
        self:append(v)
    end
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
---@return number, cg.Vertex, cg.Vertex, cg.Vertex the index, the vertex at index, the previous, and the next vertex.
--- previous and next may be nil
function Polyline:vertices(from, to)
    local i = from and from - 1 or 0
    local last = to or #self
    return function()
        i = i + 1
        if i > last then
            return nil, nil
        else
            return i, self[i], self[i - 1], self[i + 1]
        end
    end
end

--- edge iterator
---@return number, cg.LineSegment, cg.Vertex
function Polyline:edges(startIx)
    local i = startIx and startIx - 1 or 0
    return function()
        i = i + 1
        if i >= #self then
            return nil, nil, nil
        else
            return i, cg.LineSegment.fromVectors(self[i], self[i + 1]), self[i]
        end
    end
end

--- edge iterator backwards
---@return number, cg.LineSegment, cg.Vertex
function Polyline:edgesBackwards(startIx)
    local i = startIx and (startIx + 1) or (#self + 1)
    return function()
        i = i - 1
        if i < 2 then
            return nil, nil, nil
        else
            return i, cg.LineSegment.fromVectors(self[i], self[i - 1]), self[i]
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
    return self
end

function Polyline:getLength()
    if not self.length then
        self.length = 0
        for _, e in self:edges() do
            self.length = self.length + e:getLength()
        end
    end
    return self.length
end

---@return number index of the first vertex which is at least d distance from ix
---(can be nil if the end of line reached before d)
function Polyline:moveForward(ix, d)
    local i, dElapsed = ix, 0
    while i < #self do
        if dElapsed >= d then
            return i
        end
        dElapsed = dElapsed + self:at(i):getExitEdge():getLength()
        i = i + 1
    end
    return nil
end

--- Calculate all interesting properties we may need later for more advanced functions
---@param from number index of vertex to start the calculation, default 1
---@param to number index of last vertex to use in the calculation, default #self
function Polyline:calculateProperties(from, to)
    for i, current, previous, next in self:vertices(from, to) do
        current.ix = i
        current:calculateProperties(previous, next)
    end
    -- mark dirty
    self.length = nil
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

function Polyline:_cleanEdges(edges, startIx, cleanEdges, previousEdge, minEdgeLength, preserveCorners)
    for i = startIx, #edges do
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

--- Make sure the edges are properly connected, their ends touch nicely without gaps and never
--- extend beyond the vertex
---@param edges cg.LineSegment[]
function Polyline:cleanEdges(edges, minEdgeLength, preserveCorners)
    return self:_cleanEdges(edges, 2, { edges[1] }, edges[1], minEdgeLength, preserveCorners)
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
        local from = entry:getBaseAsState3D()
        local to = exit:getBaseAsState3D()
        return cg.AnalyticHelper.getDubinsSolutionAsVertices(from, to, r)
    end

    ---@param entry cg.Slider
    ---@param exit cg.Slider
    local function makeCorner(entry, exit)
        entry:extendTo(exit)
        local corner = cg.Vertex.fromVector(entry:getEnd())
        corner.isCorner = true
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
            local step, totalMoved = 0.2, 0
            repeat
                -- from the corner, start widening the gap until we can fit an
                -- arc with r between
                entry:move(-step)
                exit:move(step)
                totalMoved = totalMoved + step
                rMin = entry:getRadiusTo(exit)
                cg.addDebugPoint(entry:getBase())
                cg.addDebugPoint(exit:getBase())
            until rMin >= r
            -- entry and exit are now far enough, so use the Dubins solver to effortlessly create a nice
            -- arc between the two, or, to make it a sharp corner, find the intersection of entry and exit
            local adjustedCornerVertices
            if makeCorners then
                if totalMoved < 2 * r then
                    adjustedCornerVertices = makeCorner(entry, exit)
                else
                    -- there are cases, for instance in narrow nooks which already have turns, where
                    -- it does not make sense trying to sharpen as we'll end up a very small angle with a
                    -- corner point very far away.
                    self.logger:warning(
                            'ensureMinimumRadius: will not sharpen this corner, had to move too far (%.1f) back',
                            totalMoved)
                    self[currentIx].isCorner = true
                end
            else
                adjustedCornerVertices = makeArc(entry, exit)
            end
            if adjustedCornerVertices and #adjustedCornerVertices >= 1 then
                -- remember the size before the replacement
                local sizeBeforeReplace = #self
                -- replace the section with an arc or a corner
                nextIx, wrappedAround = self:replace(entry.ix, exit.ix + 1, adjustedCornerVertices)
                self.logger:debug('ensureMinimumRadius: replaced corner vertices between %d to %d with %d waypoint(s), continue at %d (of %d), wrapped around %s',
                        entry.ix, exit.ix, #adjustedCornerVertices, nextIx, #self, wrappedAround)
                if #self < sizeBeforeReplace then
                    self:calculateProperties(entry.ix - (sizeBeforeReplace - #self), nextIx)
                else
                    self:calculateProperties(entry.ix, nextIx)
                end
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
---@return boolean, number true if there were an intersection and we actually went around, index of last vertex
--- after the bypass
function Polyline:goAround(other, startIx, circle)
    local intersections = self:getIntersections(other, startIx)
    local is1, is2 = intersections[1], intersections[2]
    if is1 and is2 then
        local pathA, pathB = other:_getPathBetween(is1.ixB, is2.ixB)
        local path
        if pathA and pathB then
            local shortPath = pathA:getLength() < pathB:getLength() and pathA or pathB
            local longPath = pathA:getLength() >= pathB:getLength() and pathA or pathB
            self.logger:debug('path A: %.1f, path B: %.1f', pathA:getLength(), pathB:getLength())
            if circle then
                path = shortPath:clone()
                path:_setAttributes(nil, nil, cg.WaypointAttributes.setIslandBypass, true)
                longPath:reverse()
                path:appendMany(longPath)
                -- mark this roundtrip as island bypass
                path:_setAttributes(#path - #longPath, #path, cg.WaypointAttributes.setIslandBypass, true)
                path:appendMany(shortPath)
                self.logger:debug('Circled around, %d waypoints', #path)
            else
                path = shortPath
                self.logger:debug('Took the shorter path, no circle')
            end
        else
            path = pathA
        end
        table.insert(path, 1, cg.Vertex.fromVector(is1.is))
        table.insert(path, cg.Vertex.fromVector(is2.is))
        if path then
            local lastIx = self:replace(is1.ixA, is2.ixA + 1, path)
            -- make the transitions a little smoother
            cg.SplineHelper.smooth(self, 3, is1.ixA, lastIx)
            self:calculateProperties()
            return true, lastIx
        end
    end
    return false
end

---@param lineSegment cg.LineSegment
---@return cg.Vertex, number, cg.Vertex, number the vertex closest to lineSegment, its distance, the vertex
--- farthest from the lineSegment, its distance
function Polyline:findClosestAndFarthestVertexToLineSegment(lineSegment)
    local dMin, closestVertex = math.huge, nil
    local dMax, farthestVertex = -math.huge, nil
    for _, v in self:vertices() do
        local thisD = lineSegment:getDistanceFrom(v)
        if thisD < dMin then
            dMin = thisD
            closestVertex = v
        end
        if thisD > dMax then
            dMax = thisD
            farthestVertex = v
        end
    end
    return closestVertex, dMin, farthestVertex, dMax
end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function Polyline:getNextIntersection(other, startIx, backwards)
    local path = Polyline()
    for i, edge, vertex in (backwards and self:edgesBackwards(startIx) or self:edges(startIx)) do
        path:append(vertex)
        for j, otherEdge in other:edges() do
            local is = edge:intersects(otherEdge)
            if is then
                path:append(is)
                return i, j, is, path
            end
        end
    end
end

--- Get all intersections with other, in the order we would meet them traversing self in the given direction
---@param other cg.Polyline
---@param startIx number index to start looking for intersections with other
---@param backwards boolean start traversing self at startIx backwards (decreasing indices)
---@return cg.Intersection[] list of intersections
function Polyline:getIntersections(other, startIx, backwards)
    local intersections = {}
    local path = Polyline()
    for i, edge, vertex in (backwards and self:edgesBackwards(startIx) or self:edges(startIx)) do
        path:append(vertex)
        for j, otherEdge in other:edges() do
            local is = edge:intersects(otherEdge)
            if is then
                -- do not add an intersection twice if it goes exactly through a vertex
                if #intersections == 0 or (intersections[#intersections].is ~= is) then
                    path:append(is)
                    table.insert(intersections, cg.Intersection(i, j, is, edge, path))
                    path = Polyline()
                end
            end
        end
    end
    table.sort(intersections)
    return intersections
end

--- Is this polyline entering the other polygon at intersection point is?
---@param other cg.Polygon
---@param is cg.Intersection
---@return boolean true if self is entering the other polygon, false when exiting, when moving in
--- the direction of increasing indexes
function Polyline:isEntering(other, is)
    local otherEdge = other:at(is.ixB):getExitEdge()
    if other:isClockwise() then
        -- if the start of my intersecting edge is left of the polygon's intersecting edge and
        -- the polygon is clockwise, I'm entering the polygon here
        return otherEdge:isLeft(self:at(is.ixA))
    else
        -- similarly, to enter a counterclockwise polygon, my intersecting edge start vertex
        -- must be on the right when entering the polygon
        return not otherEdge:isLeft(self:at(is.ixA))
    end
end

--- Replace all vertices between fromIx and toIx (excluding) with the entries in vertices
---@param fromIx number index of last vertex to keep
---@param toIx number index of first vertex to keep, toIx must be >= fromIx, unless wrapping around on a Polygon
---@param vertices cg.Vector[] new vertices to put between fromIx and toIx
---@return number, boolean index of the next vertex after the replaced ones (may be more or less than toIx depending on
--- how many entries vertices had and how many elements were there originally between fromIx and toIx. The boolean
--- is true when wrapped around the end (for a polygon)
function Polyline:replace(fromIx, toIx, vertices)
    -- mark the ones we need to replace/remove. this is to make the rollover case (for polygons) easier
    for i = fromIx + 1, toIx - 1 do
        self[self:getRawIndex(i)].toBeReplaced = true
    end

    local sourceIx = 1
    local destIx = cg.WrapAroundIndex(self, fromIx + 1)
    while self[destIx:get()] and self[destIx:get()].toBeReplaced do
        if sourceIx <= #vertices then
            local newVertex = vertices[sourceIx]:clone()
            newVertex.color = { 0, 1, 0 } -- for debug only
            self[destIx:get()] = newVertex
            self.logger:trace('Replaced %d with %s', destIx:get(), newVertex)
            destIx = destIx + 1
        else
            table.remove(self, destIx:get())
            self.logger:trace('Removed %d', destIx:get())
            -- just in case we happened to remove the last element of the table, reset destIx to the max index
            destIx:set(destIx:get())
        end
        sourceIx = sourceIx + 1
    end
    while sourceIx <= #vertices do
        -- we have some vertices left, but there is no room for them
        local newVertex = vertices[sourceIx]:clone()
        newVertex.color = { 1, 0, 0 } -- for debug only
        table.insert(self, destIx:get(), newVertex)
        self.logger:trace('Adding %s at %d', newVertex, destIx:get())
        sourceIx = sourceIx + 1
        destIx = destIx + 1
    end
    return destIx:get(), destIx:get() < fromIx
end

--- Get a reference to a contiguous segment of vertices of a polyline. Note that
--- these are references of the original vertices, not copies!
---@param fromIx number index of first vertex in the segment, not including
---@param toIx number index of last vertex in the segment, not including
---@return Polyline
function Polyline:_getPathBetween(fromIx, toIx)
    local segment = Polyline()
    local first = fromIx < toIx and fromIx + 1 or fromIx
    local last = fromIx < toIx and toIx or toIx + 1
    local step = fromIx < toIx and 1 or -1
    for i = first, last, step do
        table.insert(segment, self:at(i))
    end
    return segment
end

--- Set an attribute for a series of vertices
---@param first number index of first vertex to set the attribute
---@param last number index of last vertex
---@param setter cg.WaypointAttributes function to call on each vertex' attributes
---@param ... any arguments for setter
function Polyline:_setAttributes(first, last, setter, ...)
    first = first or 1
    last = last or #self
    for i = first, last do
        setter(self:at(i):getAttributes(), ...)
    end
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
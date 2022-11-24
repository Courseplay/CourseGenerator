local Polyline = CpObject()

---@param vertices table[] array of tables with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:init(vertices)
    if vertices then
        for i, v in ipairs(vertices) do
            self[i] = cg.Vertex(v.x, v.y, i)
        end
    end
    self:calculateProperties()
end

function Polyline:debug(...)
    cg.debug('Polyline: ' .. string.format(...))
end

function Polyline:trace(...)
    cg.trace('Polyline: ' .. string.format(...))
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

--- Get the vertex at position n.
function Polyline:at(n)
    return self[n]
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

--- Calculate all interesting properties we may need later for more advanced functions
---@param from number index of vertex to start the calculation, default 1
---@param to number index of last vertex to use in the calculation, default #self
function Polyline:calculateProperties(from, to)
    self.deltaAngle = 0
    for i = from or 1, to or #self do
        self:at(i).ix = i
        self:at(i):calculateProperties(self:at(i - 1), self:at(i + 1))
        self.deltaAngle = self.deltaAngle + cg.Math.getDeltaAngle(self:at(i):getExitHeading(), self:at(i):getEntryHeading())
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
            self:trace('ensureMaximumEdgeLength: added a vertex after %d', i)
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

    local function replace(fromIx, toIx, vertices)
        local newIx
        for i = 1, #vertices do
            newIx = fromIx + i - 1
            local newVertex = cg.Vertex(vertices[i].x, vertices[i].y, newIx)
            newVertex.color = vertices[i].color -- for debug only
            if newIx <= toIx then
                self:trace('Replacing %s with %s at %d', self[newIx], newVertex, newIx)
                self[newIx] = newVertex
            else
                self:trace('Adding %s at %d', newVertex, newIx)
                -- vertices has more entries than fromIx -> toIx, need to insert
                table.insert(self, newIx, newVertex)
            end
        end
        for _ = 1, toIx - newIx do
            -- remove extra elements if vertices has less than the space fromIx -> toIx
            self:trace('Removing %s at %d', self[newIx + 1], newIx + 1)
            table.remove(self, newIx + 1)
        end
        return newIx + 1
    end

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
        corner.color = {0, 1, 0}
        return {corner}
    end

    local currentIx = 1
    local nextIx = currentIx + 1
    while currentIx <= #self do
        local xte = self:at(currentIx):getXte(r)
        if xte > cg.cMaxCrossTrackError then
            self:debug('ensureMinimumRadius: found a corner at %d, r: %.1f', currentIx, r)
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
            -- arc between the two

            local adjustedCornerVertices
            if makeCorners then
                adjustedCornerVertices = makeCorner(entry, exit)
            else
                adjustedCornerVertices = makeArc(entry, exit)
            end
            if adjustedCornerVertices and #adjustedCornerVertices > 1 then
                -- move the vertices to the exact entry and exit points
                self:at(entry.ix):set(entry:getBase().x, entry:getBase().y)
                self:at(exit.ix):set(exit:getBase().x, exit:getBase().y)
                currentIx = entry.ix
                nextIx = exit.ix
                -- replace the sharp section with the arc
                nextIx = replace(currentIx, nextIx, adjustedCornerVertices)
                self:debug('ensureMinimumRadius: replaced corner from %d to %d with %d waypoint(s), continue at %d (of %d)',
                        entry.ix, exit.ix, #adjustedCornerVertices, nextIx, #self)
                self:calculateProperties(currentIx, nextIx)
            else
                self:debug('ensureMinimumRadius: could not calculate adjusted corner vertices')
            end
        end
        currentIx = nextIx
        nextIx = currentIx + 1
    end
    self:ensureMinimumEdgeLength(cg.cMinEdgeLength)
    if makeCorners then
        self:ensureMaximumEdgeLength(cg.cMaxEdgeLength, cg.cMaxDeltaAngleForMaxEdgeLength)
    end
    self:calculateProperties()
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
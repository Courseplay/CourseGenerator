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

---@param v table table with x, y (Vector, Vertex, State3D or just plain {x, y}
function Polyline:append(v)
    table.insert(self, cg.Vertex(v.x, v.y, #self + 1))
end

function Polyline:at(n)
    return self[n]
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

function Polyline:vertexPairs(n, overlap)
    local i = 0
    return function()
        i = i + 1
        if i > #self then
            return nil, nil
        else
            return i, self[i], self[i + 1]
        end
    end
end

function Polyline:vertexTriplets(n, overlap)
    local i = 0
    return function()
        i = i + 1
        if i > #self then
            return nil, nil
        else
            return i, self[i], self[i + 1], self[i + 2]
        end
    end
end

function Polyline:getShortestEdge()
    local shortest = math.huge
    for _, e in self:edges() do
        shortest = math.min(shortest, e:getLength())
    end
    return shortest
end

function Polyline:calculateProperties(from, to)
    self.deltaAngle = 0
    for i = from or 1, to or #self do
        self[i].ix = i
        self[i]:calculateProperties(self:at(i - 1), self:at(i + 1))
        self.deltaAngle = self.deltaAngle + cg.Math.getDeltaAngle(self[i]:getExitHeading(), self[i]:getEntryHeading())
    end
end

--- If two vertices are closer than minimumLength, replace them with
function Polyline:ensureMinimumEdgeLength(minimumLength)
    local i = 1
    while i < #self do
        if (self[i + 1] - self[i]):length() < minimumLength then
            table.remove(self, i + 1)
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

function Polyline:getRadiusAt(i)
    local entry = self:at(i):getEntryEdge()
    if not entry then
        -- if there is no entry edge, create one from the exit
        entry = self:at(i):getExitEdge():clone()
        -- and move it back behind the vertex, so its end is now at the vertex
        entry:offset(-entry:getLength(), 0)
    end
    local exit = self:at(i + 1):getExitEdge()
    if not exit then
        -- if there is no exit edge, create one from the entry
        exit = self:at(i):getEntryEdge():clone()
        -- and move it forward beyond the vertex, so its start is now at the vertex
        exit:offset(exit:getLength(), 0)
    end
    local r = entry:getRadiusTo(exit)
    if r == 0 then
        exit = self:at(i + 2):getExitEdge()
        return entry:getRadiusTo(exit)
    else
        return r
    end
end

function Polyline:ensureMinimumRadius(r)
    --- If we find that we can't drive to the next waypoint with our turning radius then we
    -- check if we can drive to the one after the next or the one before the current. If that
    -- still does not work then we go further forward and backwards, based on the distance from
    -- the current wp.
    local function getNextVertexPairToCheck(fwdIx, lookaheadDistance, backIx, lookBackDistance)
        local fD = self:at(fwdIx):getExitEdge():getLength()
        local bD = self:at(backIx):getEntryEdge():getLength()
        if lookaheadDistance + fD < lookBackDistance + bD then
            -- extend our window forward
            return fwdIx + 1, lookaheadDistance + fD, backIx, lookBackDistance
        else
            -- extend our window backwards
            return fwdIx, lookaheadDistance, backIx - 1, lookBackDistance + bD
        end
    end

    local function replaceWithArc(fromIx, toIx)
        local dubinsSolver = DubinsSolver()
        local from = self:at(fromIx):getEntryEdge():getEndAsState3D()
        local to = self:at(toIx):getExitEdge():getBaseAsState3D()
        local solution = dubinsSolver:solve(from, to, r, true)
        local arcPoints = solution:getWaypoints(from, r)
        local newIx
        for i = 1, #arcPoints do
            newIx = fromIx + i - 1
            local newVertex = cg.Vertex(arcPoints[i].x, arcPoints[i].y, newIx)
            newVertex.color = {100, 0, 0}
            if newIx <= toIx then
                self[newIx] = newVertex
            else
                table.insert(self, newIx, newVertex)
            end
        end
        return newIx
    end

    self:calculateProperties()
    local needsArc = false
    local currentIx = 1
    local nextIx = currentIx + 1
    while currentIx < #self do
        local lookaheadDistance, lookBackDistance = 0, 0
        local rMin = self:at(currentIx):getRadius()
        while math.abs(rMin) < r do
            needsArc = true
            nextIx, lookaheadDistance, currentIx, lookBackDistance = getNextVertexPairToCheck(nextIx, lookaheadDistance,
                    currentIx, lookBackDistance)
            rMin = self:getRadiusAt(currentIx)
        end
        if needsArc then
            nextIx = replaceWithArc(currentIx, nextIx + 1)
            self:calculateProperties(currentIx, nextIx)
            needsArc = false
        end
        currentIx = nextIx
        nextIx = currentIx + 1
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
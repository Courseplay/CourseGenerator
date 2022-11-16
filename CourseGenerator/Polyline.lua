local Polyline = CpObject()

---@param vertices cg.Vector
function Polyline:init(vertices)
    if vertices then
        for i, v in ipairs(vertices) do
            self[i] = v:clone()
        end
    end
end

---@param vertex cg.Vector
function Polyline:append(vertex)
    table.insert(self, vertex)
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

function Polyline:calculateProperties()
    for i = 1, #self do
        self[i]:calculateProperties(self[i - 1], self[i + 1])
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

function Polyline:ensureMinimumRadius(r)
    local dubins = DubinsSolver()
    local edges = {}
    for _, e in self:edges() do
        table.insert(edges, e)
    end
    local i = 2
    local j = i + 1
    while i < #edges do
        print(edges[i - 1]:getRadiusTo(edges[i + 1]))
        local entry = edges[i]:getBase()
        local entryHeading = edges[i - 1]:getHeading()
        local exit = edges[i]:getEnd()
        local exitHeading = edges[i + 1]:getHeading()
        local dA = cg.Math.getDeltaAngle(exitHeading, entryHeading)
        entry = State3D(entry.x, entry.y, entryHeading - dA / 4)
        exit = State3D(exit.x, exit.y, exitHeading + dA / 4)
        local rightTurn = dA >= 0
        local solution, code = dubins:solve(entry, exit, r, true)
        local l, l1, l2, l3 = solution:getLength(r)
        --print(i, code, l1, l2, l3 , edges[i], dA, rightTurn, entry, exit)
        i = i + 1
        j = j + 1
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
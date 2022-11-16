--- Vertex of a polyline or a polygon. Besides the coordinates (as a Vector) it holds
--- all kinds of other information in the line/polygon context.

local Vertex = CpObject(cg.Vector)

function Vertex:init(x, y)
    cg.Vector.init(self, x, y)
end

function Vertex:clone()
    local v = Vertex(self.x, self.y)
    v.entryHeading = self:getEntryHeading()
    v.exitHeading = self:getExitHeading()
    v.entryEdge = self.entryEdge and self.entryEdge:clone()
    v.exitEdge = self.exitEdge and self.exitEdge:clone()
    v.radius = self.radius
    return v
end

function Vertex:getEntryEdge()
    return self.entryEdge
end

function Vertex:getEntryHeading()
    return self.entryHeading
end

function Vertex:getExitEdge()
    return self.exitEdge
end

function Vertex:getExitHeading()
    return self.exitHeading
end

--- The radius at this vertex, calculated from the direction and the length of
--- the entry/exit edges. Positive values are left turns, negative values right turns
---@return number radius
function Vertex:getRadius()
    return self.radius
end

--- Add info related to the neighbouring vertices
---@param entry cg.Vertex the previous vertex in the polyline/polygon
---@param exit cg.Vertex the next vertex in the polyline/polygon
function Vertex:calculateProperties(entry, exit)
    if entry then
        self.entryEdge = cg.LineSegment.fromVectors(entry, self)
        self.entryHeading = self.entryEdge:getHeading()
    end
    if exit then
        self.exitEdge = cg.LineSegment.fromVectors(self, exit)
        self.exitHeading = self.exitEdge:getHeading()
    end

    -- if there is no previous vertex, use the exit heading
    if not self.entryHeading then
        self.entryHeading = self.exitHeading
    end

    -- if there is no next vertex, use the entry heading (one of exit/entry must be given)
    if not self.exitHeading then
        self.exitHeading = self.entryHeading
    end
    -- A very approximate radius a vehicle moving along the polyline would have to be driving
    -- at this vertex and still reaching the next.
    local dA = cg.Math.getDeltaAngle(self.entryHeading, self.exitHeading)
    self.radius = (self.exitEdge and self.exitEdge:getLength() or math.huge) / (2 * math.sin(dA / 2))
end

---@class cg.Vertex:cg.Vector
cg.Vertex = Vertex
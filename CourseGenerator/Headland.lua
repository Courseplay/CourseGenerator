
local Headland = CpObject()

--- Create a headland from a base polygon. The headland is a new polygon, offset by width, that is, inside
--- of the base polygon.
---@param basePolygon cg.Polygon
---@param width number
---@param clockwise boolean
function Headland:init(basePolygon, width)
    if basePolygon:isClockwise() then
        -- to generate headland inside the polygon we need to offset the polygon to the right if
        -- the polygon is clockwise
        self.offsetVector = cg.Vector(0, -1)
    else
        self.offsetVector = cg.Vector(0, 1)
    end
    self.recursionCount = 0
    self.polygon = self:generate(basePolygon, width, 0)
end

--- Vertices with coordinates unpacked, to draw with love.graphics.polygon
function Headland:getUnpackedVertices()
    if not self.unpackedVertices then
        self.unpackedVertices = self.polygon:getUnpackedVertices()
    end
    return self.unpackedVertices
end

function Headland:generate(polygon, targetOffset, currentOffset)
    -- done!
    if currentOffset >= targetOffset then return polygon end

    -- limit of the number of recursions based on how far we want to go
    self.recursionCount = self.recursionCount + 1
    if self.recursionCount >  math.max( math.floor( targetOffset * 20 ), 600 ) then
        CourseGenerator.debug('Headland generation: recursion limit reached (%d)', self.recursionCount)
        return nil
    end
    -- we'll use the grassfire algorithm and approach the target offset by
    -- iteration, generating headland tracks close enough to the previous one
    -- so the resulting offset polygon can be kept clean (no intersecting edges)
    -- this can be ensured by choosing an offset small enough
    local deltaOffset = math.max(polygon:getShortestEdge() / 8, 0.01)
    currentOffset = currentOffset + deltaOffset
    polygon = polygon:createOffset(deltaOffset * self.offsetVector, 1, false)
    polygon:ensureMinimumEdgeLength(0.5)
    return self:generate(polygon, targetOffset, currentOffset)
end

---@class cg.Headland
cg.Headland = Headland
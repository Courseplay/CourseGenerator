--- An intersection point of two polylines (or polygons)
local Intersection = CpObject()

--- Create an intersection point between two edges of the polylines A and B
---@param ixA number the start index of the intersecting edge (edgeA) of polyline A
---@param ixB number the start index of the intersecting edge (edgeB) of polyline B
---@param is cg.Vector the intersection point.
---@param edgeA cg.LineSegment the edge of polygon A where where the intersection point is
---@param path cg.Polyline the list of vertices on A between this and the previous intersection, the 
--- last vertex is always the intersection point (is)
function Intersection:init(ixA, ixB, is, edgeA, path)
    self.ixA = ixA
    self.ixB = ixB
    self.is = is
    self.edgeA = edgeA
    self.path = path
end

function Intersection.__lt(a, b)
    if a.ixA == b.ixA then
        -- the other polyline intersects with the same edge, so first comes the intersection that is closer to the
        -- the start of the edge
        if (a.is - a.edgeA:getBase()):length() < (b.is - a.edgeA:getBase()):length() then
            return true
        else
            return false
        end
    else
        -- different edges, first edge comes first
        if a.ixA < b.ixA then
            return true
        else
            return false
        end
    end
end

function Intersection:__tostring()
    local str = string.format('ixA: %d, ixB: %d, is: %s, edgeA: %s, #path %d',
            self.ixA, self.ixB, self.is, self.edgeA, #self.path)
    return str
end

---@class cg.Intersection
cg.Intersection = Intersection
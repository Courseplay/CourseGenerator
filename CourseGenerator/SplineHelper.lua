local SplineHelper = {}

--- Smoothing polylines/polygons as in https://faculty.cc.gatech.edu/~jarek/courses/handouts/curves.pdf
---@param p Polyline
---@param from number start index
---@param to number end index (may be less than from, to wrap around a polygon's end
---@param s number tuck factor
function SplineHelper.tuck(p, from, to, s)
    for _, cv, pv, nv in p:vertices(from, to) do
        if pv and cv and nv then
            if cv.dA and math.abs(cv.dA) > cg.cMinSmoothingAngle then
                local m = (pv + nv) / 2
                local cm = m - cv
                cv.x, cv.y = cv.x + s * cm.x, cv.y + s * cm.y
            end
        end
    end
    p:calculateProperties(from, to)
end

--- Add a vertex between existing ones
function SplineHelper.refine(p, from, to)
    for i, cv, pv, _ in p:vertices(to, from, -1) do
        if pv and cv then
            if cv.dA and math.abs(cv.dA) > cg.cMinSmoothingAngle then
                local m = (pv + cv) / 2
                local newVertex = pv:clone()
                newVertex.x, newVertex.y = m.x, m.y
                table.insert(p, i, newVertex)
            end
        end
    end
    p:calculateProperties(from, to)
end

function SplineHelper.smooth(p, order, from, to)
    if (order <= 0) then
        return
    else
        local origSize = #p
        SplineHelper.refine(p, from, to)
        to = to + #p - origSize
        SplineHelper.tuck(p, from, to, 0.5)
        SplineHelper.tuck(p, from, to, -0.15)
        SplineHelper.smooth(p, order - 1, from, to)
    end
end

---@class SplineHelper
cg.SplineHelper = SplineHelper
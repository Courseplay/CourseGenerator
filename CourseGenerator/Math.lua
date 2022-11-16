local Math = {}

local function normalizeAngle( a )
    return a >= 0 and a or 2 * math.pi + a
end

function Math.getDeltaAngle(a, b)
    -- convert the 0 - -180 range into 180 - 360
    if math.abs( a - b ) > math.pi then
        a = normalizeAngle( a )
        b = normalizeAngle( b )
    end
    -- calculate difference in this range
    return b - a
end

--- Get the theoretical turn radius to get from 'from' to 'to', where we start at the
--- end of 'from' and end up at the base of 'to', in the same direction as the line segments
---@param from cg.LineSegment
---@param to cg.LineSegment
function Math.getTurningRadiusBetweenTwoEdges(from, to)
    local entry = from.clone()
    entry:setBase(entry:getEnd())
    local exit = to.clone()
    local dA = cg.Math.getDeltaAngle(exit:getHeading(), entry:getHeading())

    -- local dA = getDeltaAngle( to.nextEdge.angle, from.prevEdge.angle )
    -- TODO: this is true only if the two points are nearly on the same line
    -- if math.abs( dA ) < math.rad( 5 ) then return math.huge end
    -- find intersection of the two edges, extend them by at least 5 m so they intersect even with
    -- very small radius
    local is = getIntersectionOfExtendedEdges( from.prevEdge, to.nextEdge, math.max(5, targetRadius * math.pi * 2 ))
    if is then
        local dFrom = getDistanceBetweenPoints( from, is )
        local dTo = getDistanceBetweenPoints( to, is )
        local r = math.abs( math.min( dFrom, dTo ) / math.tan( dA / 2 ))
        return r
    else
        return 0
        end
end

cg.Math = Math
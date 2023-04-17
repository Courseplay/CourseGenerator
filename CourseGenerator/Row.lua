--- An up/down row (swath) in the middle of the field (the area surrounded by the field boundary or the
--- innermost headland).
local Row = CpObject(cg.Polyline)

function Row:init(vertices)
    self.logger = cg.Logger('Row', cg.Logger.level.debug)
    cg.Polyline.init(self, vertices)
end

--- Create a row parallel to this one at offset distance.
---@param offset number distance of the new row. New row will be on the left side
--- (looking at increasing vertex indices) when offset > 0, right side otherwise.
function Row:createNext(offset)
    if offset >= 0 then
        return cg.Offset.generate(self, cg.Vector(0, 1), offset)
    else
        return cg.Offset.generate(self, cg.Vector(0, -1), offset)
    end
end

function Row:createOffset(offsetVector, minEdgeLength, preserveCorners)
    local offsetRow = cg.Row()
    return self:_createOffset(offsetRow, offsetVector, minEdgeLength, preserveCorners)
end

---@class cg.Row
cg.Row = Row
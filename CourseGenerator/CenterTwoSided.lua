--- This is to encapsulate the specifics of a field center up/down rows generated
--- for the two-side headland pattern.
--- With that pattern, we always use baseline edges, that is, the rows following the
--- field edge (instead of always being straight) which, with odd shaped field may
--- result in the last rows being outside of the field boundary if we don't do anything...
-- TODO: is this really specific to the the two side pattern or could be used whenever baseline edge is used?

---@class CenterTwoSided : cg.Center
local CenterTwoSided = CpObject(cg.Center)

---@param context cg.FieldworkContext
---@param boundary cg.Polygon the field boundary
---@param headland cg.Headland|nil the innermost headland if exists
---@param startLocation cg.Vector location of the vehicle before it starts working on the center.
---@param bigIslands cg.Island[] islands too big to circle
---@param lastRow cg.Row the last row of the center (before cut), this will be added to the ones generated
function CenterTwoSided:init(context, boundary, headland, startLocation, bigIslands, lastRow)
    cg.Center.init(self, context, boundary, headland, startLocation, bigIslands, lastRow)
    self.lastRow = lastRow
end

function CenterTwoSided:_splitIntoBlocks(rows)
    table.insert(rows, self.lastRow)
    return cg.Center._splitIntoBlocks(self, rows)
end

---@class cg.CenterTwoSided : cg.Center
cg.CenterTwoSided = CenterTwoSided
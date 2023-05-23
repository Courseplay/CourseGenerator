--- A block is an area in the center of the field which can
--- be covered by one set of alternating up/down rows, simply
--- turning 180 at the row end into the next row.
---
--- Regular rectangular or simple convex fields will always have
--- just one block. More complex shapes may require splitting
--- the area into multiple blocks, depending on the row angle.
---
--- ------------     --------------
--- |    A     |     |    B       |
--- |  .....   |_____|  .....     |
--- |                             |
--- |            C                |
--- ------------------------------
--- For instance, a field like above is split into three blocks,
--- A, B and C, by the peninsula on the top, between A and B, if
--- rows are horizontal. With vertical rows the entire field
--- would be just a single block.

local Block = CpObject()

function Block:init()
    self.rows = {}
end

function Block:addRow(row)
    table.insert(self.rows, row)
end

--- Does this row overlap with this block, that is, with the last row of this block.
---@param row cg.Row
---@return boolean true if row overlaps this block or if the block has no rows
function Block:overlaps(row)
    return #self.rows == 0 or self.rows[#self.rows]:overlaps(row)
end

function Block:getPolygon()
    if not self.polygon then
        -- assuming the first and last row in the array are also the first and last geographically (all other
        -- rows are between these two) and both have the same direction
        local firstRow, lastRow = self.rows[1], self.rows[#self.rows]
        self.polygon = cg.Polygon({firstRow[1], firstRow[#firstRow], lastRow[#lastRow], lastRow[1]})
    end
    return self.polygon
end

function Block:getPath()
    if self.path == nil then
        self.path = cg.Polyline()
        for i, row in ipairs(self.rows) do
            if i % 2 == 0 then
                row:reverse()
            end
            self.path:appendMany(row)
        end
    end
    return self.path
end


---@class cg.Block
cg.Block = Block
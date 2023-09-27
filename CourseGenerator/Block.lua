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

---@param rowPattern cg.RowPattern pattern to use for the up/down rows
function Block:init(rowPattern, id)
    self.id = id or 0
    self.logger = cg.Logger('Block ' .. id)
    -- rows in the order they were added, first vertex of each row is on the same side
    self.rows = {}
    -- rows in the order they will be worked on, every second row in this sequence is reversed
    -- so we remain on the same side of the block when switching to the next row
    self.rowsInWorkSequence = {}
    self.rowPattern = rowPattern or cg.RowPatternAlternating()
end

function Block:getId()
    return self.id
end

function Block:__tostring()
    return self.id
end

function Block:addRow(row)
    row:setSequenceNumber(#self.rows + 1)
    row:setBlockNumber(self.id)
    table.insert(self.rows, row)
end

---@return number of rows in this block
function Block:getNumberOfRows()
    -- we may not have them sequenced when this is called, so can't use self.rowsInWorkSequence
    return #self.rows
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
        self.polygon = cg.Polygon({ firstRow[1], firstRow[#firstRow], lastRow[#lastRow], lastRow[1] })
    end
    return self.polygon
end

---@return cg.Row[] rows in the order they should be worked on. Every other row is reversed, so it starts at the
--- end where the previous one ends.
function Block:getRows()
    return self.rowsInWorkSequence
end

---@return cg.RowPattern.Entry[]
function Block:getPossibleEntries()
    if not self.possibleEntries then
        -- cache this as the genetic algorithm needs it frequently, also, this way
        -- a block always returns the same Entry instances so they key be used as keys in further caching
        self.possibleEntries = self.rowPattern:getPossibleEntries(self.rows)
    end
    return self.possibleEntries
end

--- Finalize this block, set the entry we will be using, rearrange rows accordingly, set all row attributes and create
--- a sequence in which the rows must be worked on
---@param entry cg.RowPattern.Entry the entry to be used for this block
---@return cg.Vertex the last vertex of the last row, the exit point from this block (to be used to find the entry
--- to the next one.
function Block:finalize(entry)
    self.logger:debug('Finalizing, entry %s', entry)
    self.logger:debug('Generating row sequence for %d rows, pattern: %s', #self.rows, self.rowPattern)
    local sequence, exit = self.rowPattern:getWorkSequenceAndExit(self.rows, entry)
    self.rowsInWorkSequence = {}
    for i, rowInfo in ipairs(sequence) do
        local row = self.rows[rowInfo.rowIx]
        self.logger:debug('row %d is now at position %d', row:getSequenceNumber(), i)
        if rowInfo.reverse then
            row:reverse()
        end
        -- need vertices close enough so the smoothing in goAround() only starts close to the island
        row:splitEdges(cg.cRowWaypointDistance)
        row:adjustLength()
        row:setRowNumber(i)
        row:setAllAttributes()
        table.insert(self.rowsInWorkSequence, row)
    end
    return exit
end

---@return cg.Vertex
function Block:getExit(entry)
    local _, exit = self.rowPattern:getWorkSequenceAndExit(self.rows, entry)
    return exit
end

function Block:getPath()
    if self.path == nil then
        self.path = cg.Polyline()
        for _, row in ipairs(self.rowsInWorkSequence) do
            self.path:appendMany(row)
        end
    end
    return self.path
end

---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
function Block:bypassSmallIsland(islandHeadlandPolygon, circle)
    local thisIslandCircled = circle
    for _, row in ipairs(self.rowsInWorkSequence) do
        thisIslandCircled = row:bypassSmallIsland(islandHeadlandPolygon, 1, not thisIslandCircled) or thisIslandCircled
        -- make sure all new bypass waypoints have the proper attributes
        row:setAllAttributes()
    end
    return thisIslandCircled
end

function Block:getEntryVertex()
    return self.rowsInWorkSequence[1][1]
end

function Block:getExitVertex()
    local lastRow = self.rowsInWorkSequence[#self.rowsInWorkSequence]
    return lastRow[#lastRow]
end

---@class cg.Block
cg.Block = Block
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

function Block:addRow(row)
    row:setSequenceNumber(#self.rows + 1)
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
        self.polygon = cg.Polygon({ firstRow[1], firstRow[#firstRow], lastRow[#lastRow], lastRow[1] })
    end
    return self.polygon
end

---@return cg.Row[] rows in the order they should be worked on. Every other row is reversed, so it starts at the
--- end where the previous one ends.
function Block:getRows()
    return self.rowsInWorkSequence
end

--- Find the entry to this block closest to start location, distance measured on the headland.
--- The purpose of this is to figure out where the vehicle should enter this block if it is currently
--- located at startLocation. The block, consisting of a series of rows, may have multiple possible
--- entry points, we pick here the one closest to the startLocation, assuming that the vehicle must
--- drive on the headland to reach the entry point from the start location.
---@param startLocation cg.Vector the location where the vehicle ended its previous path and now must
--- continue working on this block
---@param headland cg.Polygon the headland, distance between the startLocation and the entry is measured
--- along this polygon.
---@return cg.RowPattern.Entry the entry closest to the startLocation, as measured on the headland
---@return number distance between the startLocation and the closest entry on the headland
---@return cg.Polyline the path on the headland from the start location to the closest entry. Always has at least
--- one vertex
function Block:getClosestEntry(startLocation, headland)
    local startLocationVertex = headland:findClosestVertexToPoint(startLocation)
    local entries = self.rowPattern:getPossibleEntries(self.rows)
    local closestEntry, dMin, shortestPath = nil, math.huge, nil
    for _, entry in ipairs(entries) do
        local entryVertex = headland:findClosestVertexToPoint(entry.position)
        local pathOnHeadland = headland:getShortestPathBetween(startLocationVertex.ix, entryVertex.ix)
        if pathOnHeadland:getLength() < dMin then
            closestEntry = entry
            dMin = pathOnHeadland:getLength()
            shortestPath = pathOnHeadland
        end
    end
    self.logger:debug('Closest entry: %s at %.1f m', closestEntry, dMin)
    return closestEntry, dMin, shortestPath
end

--- Set the entry we will be using for this block and rearrange rows accordingly.
function Block:setEntry(entry)
    self.logger:debug('Setting entry %s', entry)
    if entry.reverseRowOrderBefore then
        cg.reverseArray(self.rows)
    end
    self.logger:debug('Generating row sequence for %d rows, pattern: %s', #self.rows, self.rowPattern)
    self.rowsInWorkSequence = {}
    for i, row in self.rowPattern:iterator(self.rows) do
        self.logger:debug('row %d is now at position %d', row:getSequenceNumber(), i)
        if i % 2 == (entry.reverseOddRows and 1 or 0) then
            row:reverse()
        end
        table.insert(self.rowsInWorkSequence, row)
    end
    if entry.reverseRowOrderAfter then
        cg.reverseArray(self.rowsInWorkSequence)
    end
    local lastRow = self.rowsInWorkSequence[#self.rowsInWorkSequence]
    return lastRow[#lastRow]
end

function Block:getPath()
    if self.path == nil then
        self.path = cg.Polyline()
        for i, row in self.rowPattern:iterator(self.rows) do
            if i % 2 == 0 then
                row:reverse()
            end
            self.path:appendMany(row)
        end
    end
    return self.path
end

---@param circle boolean when true, make a full circle on the other polygon, else just go around and continue
function Block:bypassIslands(islandHeadlandPolygon, circle)
    local thisIslandCircled = circle
    for _, row in ipairs(self.rowsInWorkSequence) do
        -- need vertices close enough so the smoothing in goAround() only starts close to the island
        row:splitEdges(cg.cRowWaypointDistance)
        thisIslandCircled = row:goAround(islandHeadlandPolygon, 1, not thisIslandCircled)
    end
    return thisIslandCircled
end

---@class cg.Block
cg.Block = Block
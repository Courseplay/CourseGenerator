--- Generate the up/down rows covering the center part of the field,
--- within the headlands (or the field boundary if there are no headlands)
local Center = CpObject()

---@param context cg.FieldworkContext
---@param boundary cg.Polygon
function Center:init(context, boundary, hasHeadland)
    self.logger = cg.Logger('Center', cg.Logger.level.trace)
    self.boundary = boundary
    self.context = context
    self.hasHeadland = hasHeadland
    self.path = cg.Polyline()
end

---@return cg.Polyline
function Center:getPath()
    return self.path
end

---@return cg.Block[]
function Center:getBlocks()
    return self.blocks
end

--- Return the set of rows covering the entire field center, uncut. For debug purposes only.
---@return cg.Row[]
function Center:getDebugRows()
    return self.rows
end

function Center:generate()
    if self.context.useBaselineEdge then
        self.rows = self:_generateCurvedUpDownRows()
    else
        local angle = self.context.autoRowAngle and self:_findBestRowAngle() or self.context.rowAngle
        self.rows = self:_generateStraightUpDownRows(angle)
    end
    self.blocks = self:_splitIntoBlocks(self.rows)
    self.logger:debug('Found %d blocks.', #self.blocks)
end

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function Center:_generateStraightUpDownRows(rowAngle, suppressLog)
    local baseline = self:_createStraightBaseline(rowAngle)
    local _, dMin, _, dMax = self.boundary:findClosestAndFarthestVertexToLineSegment(baseline[1]:getExitEdge())
    -- move the baseline to the edge of the area we want to cover
    baseline = baseline:createNext(dMin)

    local nRows, firstRowOffset, width, lastRowOffset = self:_calculateRowDistribution(
            self.context.workingWidth, dMax - dMin,
            self.hasHeadland, self.context.evenRowDistribution, true)

    local rows = {}
    -- first row
    local row = baseline:createNext(firstRowOffset)
    table.insert(rows, row)
    if nRows > 1 then
        -- more rows
        for _ = 2, nRows - 1 do
            row = row:createNext(width)
            table.insert(rows, row)
        end
        -- last row
        row = row:createNext(lastRowOffset)
        table.insert(rows, row)
    end
    if not suppressLog then
        self.logger:debug('Created %d rows at %d° to cover an area %.1f wide, width %.1f/%.1f/%.1f m',
                nRows, math.deg(rowAngle), dMax - dMin, firstRowOffset, width or 0, lastRowOffset or 0)
        self.logger:debug('    has headland %s, even distribution %s, remainder last %s',
                self.hasHeadland, self.context.evenRowDistribution, true)
    end
    return rows
end

function Center:_findBestRowAngle()
    local minScore, minRows, bestAngle = math.huge, math.huge, 0
    for a = -90, 90, 1 do
        local rows = self:_generateStraightUpDownRows(math.rad(a), true)
        local blocks = self:_splitIntoBlocks(rows)
        local score = 10 * #blocks + #rows
        if score < minScore then
            minScore = score
            bestAngle = math.rad(a)
        end
    end
    self.logger:debug('  best row angle is %.1f', math.deg(bestAngle))
    return bestAngle
end

---@return cg.Row
function Center:_createStraightBaseline(rowAngle)
    -- Set up a baseline. This goes through the lower left or right corner of the bounding box, at the requested
    -- angle, and long enough that when shifted (offset copies are created), will cover the field at any angle.
    local x1, y1, x2, y2 = self.boundary:getBoundingBox()
    -- add a little margin so all lines are a little longer than they should be, this way
    -- we guarantee that the first intersection with the boundary will always be well defined and won't
    -- fall exactly on the boundary.
    local margin = 1
    local w, h = x2 - x1 + margin, y2 - y1 + margin
    local baselineStart, baselineEnd
    if rowAngle >= 0 then
        local lowerLeft = cg.Vector(x1 - margin / 2, y1 - margin / 2)
        baselineStart = lowerLeft - cg.Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerLeft + cg.Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
    else
        local lowerRight = cg.Vector(x2 + margin / 2, y1 - margin / 2)
        baselineStart = lowerRight - cg.Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerRight + cg.Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
    end
    return cg.Row({ baselineStart, baselineEnd })
end

--- Calculate how many rows we need with a given work width to fully cover a field and how far apart those
--- rows should be. Usually the field width can't be divided with the working width without remainder.
--- There are several ways to deal with the remainder:
---   1. reduce the width of each row so they all have the same width. This results in overlap in every row
---      and if multiple vehicles work with the same course they may collide anywhere
---   2. reduce the width of one row (usually the first or last) only, others remain same as working width.
---      There is no overlap here except in the one remainder row.
---   3. leave the width of all rows the same working width. Here, part of the first or last row will be
---      outside of the field (work width * number of rows > field width) which may be the preferred solution
---      if there is a headland, as the remainder will overlap with the headland. With no headland the
---      remainder may have obstacles like fences or trees as it is outside of the field.
---@return number, number, number, number number of rows, offset of first row from the field edge, offset of
--- rows from the previous row for the next rows, offset of last row from the next to last row.
function Center:_calculateRowDistribution(workingWidth, fieldWidth, hasHeadland, sameWidth, remainderLast)
    local nRows = math.floor(fieldWidth / workingWidth) + 1
    if nRows == 1 then
        if remainderLast then
            return nRows, workingWidth / 2, nil, nil
        else
            return nRows, fieldWidth - workingWidth / 2, nil, nil
        end
    else
        local width
        if sameWidth then
            -- #1
            width = (fieldWidth - workingWidth) / (nRows - 1)
        else
            -- #2
            width = workingWidth
        end
        local firstRowOffset, lastRowOffset
        if hasHeadland then
            -- #3
            firstRowOffset = workingWidth
            lastRowOffset = width
            -- if we have a headland, we can stay a full working width away from it and still
            -- cover everything, so we need one row less
            nRows = nRows - 1
        else
            -- #1 and #2
            firstRowOffset = workingWidth / 2
            lastRowOffset = fieldWidth - firstRowOffset - width * (nRows - 2) - workingWidth / 2
        end
        if not remainderLast then
            firstRowOffset, lastRowOffset = lastRowOffset, firstRowOffset
        end
        return nRows, firstRowOffset, width, lastRowOffset
    end
end

function Center:_generateCurvedUpDownRows()
    local rows = {}

    local function getIntersectionsExtending(row, boundary)
        local intersections, extensions = {}, 0
        repeat
            intersections = row:getIntersections(boundary, 1)
            if #intersections < 2 then
                row:extend(50)
                row:extend(-50)
                extensions = extensions + 1
            end
        until #intersections > 1 or extensions > 3
        if #intersections > 1 and extensions > 0 then
            self.logger:debug('Row %d extended to intersect boundary', #rows + 1)
        elseif #intersections < 2 then
            self.logger:debug('Row %d could not be extended to intersect boundary (tries: %d)', #rows + 1, extensions)
        end
        return intersections
    end

    local baseline = self:_createCurvedBaseline()
    baseline:extend(50)
    baseline:extend(-50)
    local row = baseline:createNext(self.context.workingWidth)
    getIntersectionsExtending(row, self.boundary)
    table.insert(rows, row)
    repeat
        row = row:createNext(self.context.workingWidth)
        local intersections = getIntersectionsExtending(row, self.boundary)
        table.insert(rows, row)
    until #rows > 100 or #intersections < 2
    return rows
end

--- Create a baseline for the up/down rows, which is not necessarily straight, instead, it follows a section
--- of the field boundary. This way some odd-shaped fields can be covered with less turns.
function Center:_createCurvedBaseline()
    local closest = self.boundary:findClosestVertexToPoint(self.context.baselineEdge or self.boundary:at(1))
    return self:_findLongestStraightSection(closest.ix, 10)
end

---@param ix number the vertex of the boundary to start the search
---@param radiusThreshold number straight section ends when the radius is under this threshold
---@return cg.Row array of vectors (can be empty) from ix to the start of the straight section
function Center:_findLongestStraightSection(ix, radiusThreshold)
    local i = ix
    local section = cg.Row()
    while math.abs(self.boundary:at(i):getRadius()) > radiusThreshold do
        section:append((self.boundary:at(i)):clone())
        i = i - 1
    end
    section:reverse()
    i = ix + 1
    while math.abs(self.boundary:at(i):getRadius()) > radiusThreshold do
        section:append((self.boundary:at(i)):clone())
        i = i + 1
    end
    section:calculateProperties()
    -- no straight section found, bail out here
    self.logger:debug('Longest straight section found %d vertices, %.1f m', #section, section:getLength())
    cg.addDebugPolyline(section)
    return section
end

---@param rows cg.Row[]
function Center:_splitIntoBlocks(rows)
    local blocks = {}
    local openBlocks = {}
    local function closeBlocks(rowNumber)
        local n = 0
        for block, lastRowNumber in pairs(openBlocks) do
            if rowNumber == nil or lastRowNumber ~= rowNumber then
                table.insert(blocks, block)
                openBlocks[block] = nil
                n = n + 1
            end
        end
        self.logger:trace('  closed %d blocks for row %s', n, rowNumber)
    end

    for i, row in ipairs(rows) do
        local sections = row:split(self.boundary)
        self.logger:trace('Row %d has %d section(s)', i, #sections)
        for j, section in ipairs(sections) do
            self.path:appendMany(section)
            -- with how many existing blocks does this row overlap?
            local overlappedBlocks = {}
            for block, _ in pairs(openBlocks) do
                if block:overlaps(section) then
                    table.insert(overlappedBlocks, block)
                end
            end
            self.logger:trace('  %.1f m, %d vertices, overlaps with %d block(s)',
                    section:getLength(), #section, #overlappedBlocks)
            if #overlappedBlocks == 0 or #overlappedBlocks > 1 then
                local newBlock = cg.Block()
                newBlock:addRow(section)
                -- remember that we added a section for row #i
                openBlocks[newBlock] = i
                self.logger:trace('  %d block(s) closed, opened a new one', #overlappedBlocks)
            else
                -- overlaps with exactly one block, add this row to the overlapped block
                overlappedBlocks[1]:addRow(section)
                -- remember that we added a section for row #i
                openBlocks[overlappedBlocks[1]] = i
            end
        end
        -- close all open blocks where we did not add a section of this row
        -- as we want all blocks to have a series of rows without gaps
        closeBlocks(i)
    end
    closeBlocks()
    return blocks
end

---@class cg.Center
cg.Center = Center
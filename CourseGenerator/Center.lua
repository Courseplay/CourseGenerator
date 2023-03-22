--- Generate the up/down rows covering the center part of the field,
--- within the headlands (or the field boundary if there are no headlands)
local Center = CpObject()

---@param context cg.FieldworkContext
---@param boundary cg.Polygon
function Center:init(context, boundary, hasHeadland)
    self.logger = cg.Logger('Center')
    self.boundary = boundary
    self.context = context
    self.hasHeadland = hasHeadland
end

---@return cg.Polyline
function Center:getPath()
    return self.path
end

function Center:generate()
    local bestAngle = self:findBestRowAngle()
    local rows = self:generateUpDownRows(bestAngle)
    self.path = cg.Polyline()
    for _, row in ipairs(rows) do
        self.path:appendMany(row)
    end
end

function Center:findBestRowAngle()
    local minRows, bestAngle = math.huge, 0
    for a = -90, 90, 1 do
        local rows = self:generateUpDownRows(math.rad(a), true)
        if #rows < minRows then
            minRows = #rows
            bestAngle = math.rad(a)
        end
    end
    return bestAngle
end

function Center:generateUpDownRows(rowAngle, suppressLog)
    -- Set up a baseline. This goes through the lower left or right corner of the bounding box, at the requested
    -- angle, and long enough that when shifted (offset copies are created), will cover the field at any angle.
    local x1, y1, x2, y2 = self.boundary:getBoundingBox()
    local w, h = x2 - x1, y2 - y1
    local baselineStart, baselineEnd
    if rowAngle >= 0 then
        local lowerLeft = cg.Vector(x1, y1)
        baselineStart = lowerLeft - cg.Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerLeft + cg.Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
    else
        local lowerRight = cg.Vector(x2, y1)
        baselineStart = lowerRight - cg.Vector(w * math.cos(rowAngle), 0):setHeading(-rowAngle)
        baselineEnd = lowerRight + cg.Vector(h * math.sin(rowAngle), 0):setHeading(-rowAngle)
    end
    local row = cg.Polyline({ baselineStart, baselineEnd })
    row:calculateProperties()
    local _, dMin, _, dMax = self.boundary:findClosestAndFarthestVertexToLineSegment(row[1]:getExitEdge())
    -- move the baseline to the edge of the area we want to cover
    row = row:createOffset(cg.Vector(0, dMin), math.huge)

    local nRows, firstRowOffset, width, lastRowOffset = self:calculateRowDistribution(
            self.context.workingWidth, dMax - dMin,
            self.hasHeadland, self.context.evenRowDistribution, true)

    local rows = {}
    row = row:createOffset(cg.Vector(0, firstRowOffset), math.huge)
    table.insert(rows, row)
    if nRows > 1 then
        for _ = 2, nRows - 1 do
            row = row:createOffset(cg.Vector(0, width), math.huge)
            table.insert(rows, row)
        end
        row = row:createOffset(cg.Vector(0, lastRowOffset), math.huge)
        table.insert(rows, row)
    end
    if not suppressLog then
        self.logger:debug('Created %d rows at %d° to cover an area %.1f wide, width %.1f/%.1f/%.1f m',
                nRows, math.deg(rowAngle), dMax - dMin, firstRowOffset, width, lastRowOffset)
        self.logger:debug('    has headland %s, even distribution %s, remainder last %s',
                self.hasHeadland, self.context.evenRowDistribution, true)
    end
    return rows
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
function Center:calculateRowDistribution(workingWidth, fieldWidth, hasHeadland, sameWidth, remainderLast)
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

---@class cg.Center
cg.Center = Center
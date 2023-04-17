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
    local rows
    if self.context.useBaselineEdge then
        rows = self:_generateCurvedUpDownRows()
    else
        local angle = self.context.autoRowAngle and self:_findBestRowAngle() or self.context.rowAngle
        rows = self:_generateStraightUpDownRows(angle)
    end
    self.path = cg.Polyline()
    for i, row in ipairs(rows) do
        row = self:_splitRow(row, self.boundary)
        self.logger:debug('Row %d has %d section(s)', i, #row)
        for j, section in ipairs(row) do
            self.logger:debug('  %.1f m, %d vertices', section:getLength(), #section)
            -- TODO: properly connect up down rows
            if i % 2 == 0 then section:reverse() end
            self.path:appendMany(section)
        end
    end
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
    local minRows, bestAngle = math.huge, 0
    for a = -90, 90, 1 do
        local rows = self:_generateStraightUpDownRows(math.rad(a), true)
        if #rows < minRows then
            minRows = #rows
            bestAngle = math.rad(a)
        end
    end
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

--- Split a row at its intersections with boundary. In the trivial case of a rectangular field,
--- this returns an array with a single polyline element, the line between the two points where
--- the row intersects the boundary.
---
--- In complex cases, with concave fields, the result may be more than one segments (polylines)
--- so for any section of the row which is within the boundary there'll be one entry in the
--- returned array.
---
---@param row cg.Polyline the row
---@param boundary cg.Polygon the field boundary (or innermost headland)
---@return cg.Polyline[]
function Center:_splitRow(row, boundary)
    local intersections = row:getIntersections(boundary, 1)
    if #intersections < 2 then
        self.logger:warning('Row has only %d intersection with boundary', #intersections)
        return cg.Polyline()
    end
    -- The assumption here is that the row always begins outside of the boundary


    -- This latter condition is to properly handle the cases where the boundary intersects with
    -- itself, for instance with fields where the total width of headlands are greater than the
    -- field width (irregularly shaped fields, like ones with a peninsula)
    -- we start outside of the boundary. If we cross it entering, we'll decrement this, if we cross leaving, we'll increment it.
    local outside = 1
    local lastInsideIx
    local sections = {}
    for i = 1, #intersections do
        local isEntering = row:isEntering(boundary, intersections[i])
        outside = outside + (isEntering and -1 or 1)
        if not isEntering and outside == 1 then
            -- exiting the polygon and we were inside before (outside was 0)
            -- create a section here
            table.insert(sections, row:cutAtIntersections(intersections[lastInsideIx], intersections[i]))
        elseif isEntering then
            lastInsideIx = i
        end
    end
    return sections
end

function Center:_generateCurvedUpDownRows()
    local rows = {}
    local baseline = self:_createCurvedBaseline()
    baseline:extend(50)
    baseline:extend(-50)
    local row = baseline:createNext(self.context.workingWidth)

    table.insert(rows, row)
    repeat
        row = row:createNext(self.context.workingWidth)
        row:extend(50)
        row:extend(-50)
        local intersections = row:getIntersections(self.boundary, 1)
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

---@class cg.Center
cg.Center = Center
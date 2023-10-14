--- Not the best name for it, but this is a fieldwork course where the headland is not
--- going around the field boundary, only two, opposite sides, think about a long
--- horizontal rectangle, the headlands would be on the left and right side of the
--- field only. Here an example starting on the left side:
--  , ,-, ,-----------------------------2-----------------------------,
--  | | | | ,---------------------------------------------------, ,-, |
--  | | | | '-------------------------------------------------, | | | |
--  | |1| | ,---------------------------4---------------------' | |3| |
--  | | | | '-------------------------------------------------, | | | |
--  '-' '-' --------------------------------------------------' '-' '-'

---@class FieldworkCourseTwoSided : cg.FieldworkCourse
local FieldworkCourseTwoSided = CpObject(cg.FieldworkCourse)

function FieldworkCourseTwoSided:init(context)
    self.logger = cg.Logger('FieldworkCourseTwoSided')
    self:_setContext(context)
    self.virtualHeadland = cg.FieldworkCourseHelper.createVirtualHeadland(self.boundary, self.context.headlandClockwise,
            self.context.workingWidth)
    self.headlandPath = cg.Polyline()
    self.circledIslands = {}
    self:setupAndSortIslands()

    -- this is the side where we start working, generate here headlands parallel to the field edge
    -- block 1 on the drawing above
    self:_createStartHeadlandBlock()
    if self.startHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError(self.logger, 'Can\'t generate headlands on start side for this field with the current settings')
        return
    end
    -- now fill in the space between the headlands with rows parallel to the edge between the start and end,
    -- this is the block 3 on the drawing above (just a single row)
    local startHeadlandBlockExit = self.startHeadlandBlock:getExit(self.startHeadlandBlockEntry)
    self:_createCenterHeadlandBlock(startHeadlandBlockExit)
    if self.centerHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError(self.logger, 'Can\'t generate headland row for this field with the current settings')
        return
    end

    -- find the opposite end of the field ...
    local center = self.boundary:getCenter()
    local oppositeBaselineLocation = center - (self.startHeadlandBlock:getRows()[1]:getMiddle() - center)
    -- ... and generate headlands over there too, block 2 on the drawing above
    self:_createEndHeadlandBlock(oppositeBaselineLocation, self.centerHeadlandBlock:getRows()[1])
    if self.endHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError(self.logger, 'Can\'t generate headlands on ending side for this field with the current settings')
        return
    end

    -- now find the entry to the end block and finalize it
    local centerHeadlandBlockExit = self.centerHeadlandBlock:getExit(self.centerHeadlandBlockEntry)
    self.endHeadlandBlock:finalize(self:_getClosestEntry(self.endHeadlandBlock, centerHeadlandBlockExit))

    -- connect the start and the center
    local lastStartHeadlandRow = self.startHeadlandBlock:getLastRow()
    local intersections = lastStartHeadlandRow:getIntersections(self.centerHeadlandBlock:getFirstRow())
    lastStartHeadlandRow:cutEndAtIx(intersections[1].ixA)
    lastStartHeadlandRow:append(intersections[1].is)
    self.centerHeadlandBlock:getFirstRow():cutStartAtIx(intersections[1].ixB + 1)

    -- connect the center and the end
    local firstEndHeadlandRow = self.endHeadlandBlock:getFirstRow()
    intersections = firstEndHeadlandRow:getIntersections(self.centerHeadlandBlock:getFirstRow())
    if #intersections > 0 then
        firstEndHeadlandRow:cutStartAtIx(intersections[1].ixA + 1)
        self.centerHeadlandBlock:getFirstRow():cutEndAtIx(intersections[1].ixB)
        self.centerHeadlandBlock:getFirstRow():append(intersections[1].is)
    else
        self.context:addError(self.logger, 'Can\'t connect headlands for this field with the current settings')
        return
    end
    self.centerBoundary = self:_createCenterBoundary()
    if self.centerBoundary == nil then
        self.context:addError(self.logger, 'Can\'t create center boundary for this field with the current settings')
        return
    end
    -- this is the headland around the center part, that is, the area #4 on the drawing above
    self.centerHeadland = cg.Headland(self.centerBoundary, self.centerBoundary:isClockwise(), 0, 0, true)

    local lastHeadlandRow = self.endHeadlandBlock:getLastRow()
    self.context.baselineEdge = self.centerHeadlandBlock:getFirstRow():getCenter()
    cg.addDebugPoint(self.context.baselineEdge)
    self.center = cg.Center(self.context, self.boundary, self.centerHeadland, lastHeadlandRow[#lastHeadlandRow] , self.bigIslands)
    self.center:generate()
end

---@return cg.Polyline
function FieldworkCourseTwoSided:getHeadlandPath()
    local headlandPath = cg.Polyline()
    for _, r in ipairs(self.startHeadlandBlock:getRows()) do
        headlandPath:appendMany(r)
    end
    for _, r in ipairs(self.centerHeadlandBlock:getRows()) do
        headlandPath:appendMany(r)
    end
    for _, r in ipairs(self.endHeadlandBlock:getRows()) do
        headlandPath:appendMany(r)
    end
    self.logger:debug('headland path with %d vertices', #headlandPath)
    return headlandPath
end

---@return cg.Polyline
function FieldworkCourseTwoSided:getCenterPath()
    local centerPath = self.center:getPath()
    return centerPath
end

--- Create headland at the starting end of the field
function FieldworkCourseTwoSided:_createStartHeadlandBlock()
    -- use the boundary directly as the baseline edge and not the virtual headland to preserve corners
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.boundary, self.context.baselineEdge,
            self.context.workingWidth, self.context.turningRadius, self.context.nHeadlands, self.context.workingWidth / 2)
    self.startSideBoundary = rows[#rows]:clone()
    cg.addDebugPolyline(self.startSideBoundary, {1, 1, 0, 0.3})
    self.startHeadlandBlock = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), 1)
    self.startHeadlandBlock:addRows(self:_cutAtBoundary(rows, self.virtualHeadland))
    self.startHeadlandBlockEntry = self:_getClosestEntry(self.startHeadlandBlock, self.context.startLocation)
    self.startHeadlandBlock:finalize(self.startHeadlandBlockEntry)
end

--- Create headland at the ending side of the field
function FieldworkCourseTwoSided:_createEndHeadlandBlock(oppositeBaselineLocation, centerHeadlandRow)
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.boundary, oppositeBaselineLocation,
            self.context.workingWidth, self.context.turningRadius, self.context.nHeadlands, self.context.workingWidth / 2)
    self.endSideBoundary = rows[#rows]:clone()
    cg.addDebugPolyline(self.endSideBoundary, {1, 1, 0, 0.3})
    self.endHeadlandBlock = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), 3)
    rows = self:_cutAtBoundary(rows, self.virtualHeadland)
    -- on this side, we are working our way back from the field edge, so the first row is connected
    -- to the center, but all the rest must be trimmed back
    for i = 2, #rows do
        self:_trim(rows[i], centerHeadlandRow)
    end
    self.endHeadlandBlock:addRows(rows)
end

--- Create headland connecting the two above, this is a single row
function FieldworkCourseTwoSided:_createCenterHeadlandBlock(startHeadlandBlockExit)
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.virtualHeadland:getPolygon(), startHeadlandBlockExit,
            self.context.workingWidth, self.context.turningRadius, 1)
    self.centerSideBoundary = rows[#rows]:clone()
    cg.addDebugPolyline(self.centerSideBoundary, {1, 1, 0, 0.3})
    self.centerHeadlandBlock = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), 2)
    self.centerHeadlandBlock:addRows(self:_cutAtBoundary(rows, self.virtualHeadland))
    self.centerHeadlandBlockEntry = self:_getClosestEntry(self.centerHeadlandBlock, startHeadlandBlockExit)
    self.centerHeadlandBlock:finalize(self.centerHeadlandBlockEntry)
end

function FieldworkCourseTwoSided:_cutAtBoundary(rows, boundary)
    local cutRows = {}
    for _, row in ipairs(rows) do
        local sections = row:split(boundary, {}, true)
        if #sections == 1 then
            table.insert(cutRows, sections[1])
        end
    end
    return cutRows
end

function FieldworkCourseTwoSided:_getClosestEntry(block, startLocation)
    local minD, closestEntry = math.huge, nil
    for _, e in pairs(block:getPossibleEntries()) do
        local d = cg.Vector.getDistance(startLocation, e.position)
        if d < minD then
            minD, closestEntry = d, e
        end
    end
    return closestEntry
end

--- Trim a row of the ending headland at the center headland row leading to the end of the field
---@return boolean true if row was trimmed at the start
function FieldworkCourseTwoSided:_trim(row, centerHeadlandRow)
    local intersections = row:getIntersections(centerHeadlandRow)
    if #intersections == 0 then
        return
    end
    -- where is the longer part?
    local is = intersections[1]
    local lengthFromIntersectionToEnd = row:getLength(is.ixA)
    if lengthFromIntersectionToEnd < row:getLength() / 2 then
        -- shorter part towards the end
        row:cutEndAtIx(is.ixA)
        row:append(is.is)
        row:calculateProperties()
        return false
    else
        -- shorter part towards the start
        row:cutStartAtIx(is.ixA + 1)
        row:prepend(is.is)
        row:calculateProperties()
        return true
    end
    -- Block:finalize() will adjust the row length according to the headland angle
end

--- Trim a at the first intersection with b, and flip a so that its last
--- vertex is at the intersection
function FieldworkCourseTwoSided:_trimAndFlip(a, b)
    local cutAtStart = self:_trim(a, b)
    if cutAtStart ~= nil and cutAtStart == false then
        a:reverse()
    end
end

--- Create the boundary around the center from the headlands we generated on three sides and
--- from the field boundary
function FieldworkCourseTwoSided:_createCenterBoundary()
    local centerBoundary = cg.Polygon()
    -- connect the start side to the center
    centerBoundary:appendMany(self.startHeadlandBlock:getLastRow())
    centerBoundary:appendMany(self.centerHeadlandBlock:getFirstRow())
    local is = centerBoundary:getIntersections(self.endSideBoundary)[1]
    if is == nil then
        return
    end
    centerBoundary:cutEndAtIx(is.ixA)
    centerBoundary:append(is.is)
    centerBoundary:calculateProperties()
    -- connect the center to the end side
    local endingRow = self.endHeadlandBlock:getLastRow():clone()
    if self.context.nHeadlands % 2 == 0 then
        endingRow:reverse()
    end
    centerBoundary:appendMany(endingRow)
    -- Now we have three sides, need to close the polygon now on the fourth side
    -- Instead of using the field boundary directly, we generate one row following the boundary and will
    -- use that as the fourth side. We'll also use this same row as the last row of the center later.
    -- This is to prevent the center rows going outside the field boundary which may be the case with irregularly
    -- shaped fields. Also, with curved up/down rows, there is no precise row distribution calculation and the last
    -- row may partially be outside of the field. Creating this last row parallel to the field boundary should
    -- prevent all this.
    -- This is somewhere around the center of the field edge opposite to the center headland piece connecting
    -- to the starting and ending side
    local baselineLocation = (centerBoundary[1] + centerBoundary[#centerBoundary]) / 2
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.virtualHeadland:getPolygon(), baselineLocation,
            self.context.workingWidth, self.context.turningRadius, 1)
    local lastRow = rows[1]
    local intersections = lastRow:getIntersections(centerBoundary)
    local startIs, endIs = intersections[1], intersections[#intersections]
    cg.addDebugPoint(startIs.is, 'start' .. #intersections)
    cg.addDebugPoint(endIs.is, 'end')
    if startIs.ixB > endIs.ixB then
        startIs, endIs = endIs, startIs
    end
    if startIs.ixA < endIs.ixA then
        lastRow:cutEndAtIx(endIs.ixA)
        lastRow:cutStartAtIx(startIs.ixA + 1)
        lastRow:reverse()
    else
        lastRow:cutEndAtIx(startIs.ixA)
        lastRow:cutStartAtIx(endIs.ixA + 1)
    end
    centerBoundary:cutEndAtIx(endIs.ixB)
    centerBoundary:cutStartAtIx(startIs.ixB + 1)
    centerBoundary:append(endIs.is)
    centerBoundary:appendMany(lastRow)
    centerBoundary:append(startIs.is)
    centerBoundary:calculateProperties()
    cg.addDebugPolyline(centerBoundary, {0, 0, 1, 1})
    return centerBoundary
end

---@class cg.FieldworkCourseTwoSided : cg.FieldworkCourse
cg.FieldworkCourseTwoSided = FieldworkCourseTwoSided
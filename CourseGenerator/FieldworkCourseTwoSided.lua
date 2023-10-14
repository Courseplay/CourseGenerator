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
--
-- 1: start headland block
-- 2: middle headland block
-- 3: end headland block
-- 4: center

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
    self:_createMiddleHeadlandBlock(startHeadlandBlockExit)
    if self.middleHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError(self.logger, 'Can\'t generate headland row for this field with the current settings')
        return
    end

    -- find the opposite end of the field ...
    local center = self.boundary:getCenter()
    local oppositeBaselineLocation = center - (self.startHeadlandBlock:getRows()[1]:getMiddle() - center)
    -- ... and generate headlands over there too, block 2 on the drawing above
    self:_createEndHeadlandBlock(oppositeBaselineLocation, self.middleHeadlandBlock:getRows()[1])
    if self.endHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError(self.logger, 'Can\'t generate headlands on ending side for this field with the current settings')
        return
    end

    -- now find the entry to the end block and finalize it
    local middleHeadlandBlockExit = self.middleHeadlandBlock:getExit(self.middleHeadlandBlockEntry)
    self.endHeadlandBlock:finalize(self:_getClosestEntry(self.endHeadlandBlock, middleHeadlandBlockExit))

    -- connect the start and the middle
    local lastStartHeadlandRow = self.startHeadlandBlock:getLastRow()
    local intersections = lastStartHeadlandRow:getIntersections(self.middleHeadlandBlock:getFirstRow())
    lastStartHeadlandRow:cutEndAtIx(intersections[1].ixA)
    lastStartHeadlandRow:append(intersections[1].is)
    self.middleHeadlandBlock:getFirstRow():cutStartAtIx(intersections[1].ixB + 1)

    -- connect the middle and the end
    local firstEndHeadlandRow = self.endHeadlandBlock:getFirstRow()
    intersections = firstEndHeadlandRow:getIntersections(self.middleHeadlandBlock:getFirstRow())
    if #intersections > 0 then
        firstEndHeadlandRow:cutStartAtIx(intersections[1].ixA + 1)
        self.middleHeadlandBlock:getFirstRow():cutEndAtIx(intersections[1].ixB)
        self.middleHeadlandBlock:getFirstRow():append(intersections[1].is)
    else
        self.context:addError(self.logger, 'Can\'t connect headlands for this field with the current settings')
        return
    end
    local centerBoundary, lastRow = self:_createCenterBoundary()
    if centerBoundary == nil then
        self.context:addError(self.logger, 'Can\'t create center boundary for this field with the current settings')
        return
    end
    -- this is the headland around the center part, that is, the area #4 on the drawing above
    self.middleHeadland = cg.Headland(centerBoundary, centerBoundary:isClockwise(), 0, 0, true)

    local lastHeadlandRow = self.endHeadlandBlock:getLastRow()
    self.context.baselineEdge = self.middleHeadlandBlock:getFirstRow():getCenter()
    cg.addDebugPoint(self.context.baselineEdge)
    self.center = cg.CenterTwoSided(self.context, self.boundary, self.middleHeadland, lastHeadlandRow[#lastHeadlandRow] ,
            self.bigIslands, lastRow)
    self.center:generate()
end

---@return cg.Polyline
function FieldworkCourseTwoSided:getHeadlandPath()
    local headlandPath = cg.Polyline()
    for _, r in ipairs(self.startHeadlandBlock:getRows()) do
        headlandPath:appendMany(r)
    end
    for _, r in ipairs(self.middleHeadlandBlock:getRows()) do
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
function FieldworkCourseTwoSided:_createEndHeadlandBlock(oppositeBaselineLocation, middleHeadlandRow)
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.boundary, oppositeBaselineLocation,
            self.context.workingWidth, self.context.turningRadius, self.context.nHeadlands, self.context.workingWidth / 2)
    self.endSideBoundary = rows[#rows]:clone()
    cg.addDebugPolyline(self.endSideBoundary, {1, 1, 0, 0.3})
    self.endHeadlandBlock = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), 3)
    rows = self:_cutAtBoundary(rows, self.virtualHeadland)
    -- on this side, we are working our way back from the field edge, so the first row is connected
    -- to the center, but all the rest must be trimmed back
    for i = 2, #rows do
        self:_trim(rows[i], middleHeadlandRow)
    end
    self.endHeadlandBlock:addRows(rows)
end

--- Create headland connecting the two above, this is a single row
function FieldworkCourseTwoSided:_createMiddleHeadlandBlock(startHeadlandBlockExit)
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(self.virtualHeadland:getPolygon(), startHeadlandBlockExit,
            self.context.workingWidth, self.context.turningRadius, 1)
    self.centerSideBoundary = rows[#rows]:clone()
    cg.addDebugPolyline(self.centerSideBoundary, {1, 1, 0, 0.3})
    self.middleHeadlandBlock = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), 2)
    self.middleHeadlandBlock:addRows(self:_cutAtBoundary(rows, self.virtualHeadland))
    self.middleHeadlandBlockEntry = self:_getClosestEntry(self.middleHeadlandBlock, startHeadlandBlockExit)
    self.middleHeadlandBlock:finalize(self.middleHeadlandBlockEntry)
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
function FieldworkCourseTwoSided:_trim(row, middleHeadlandRow)
    local intersections = row:getIntersections(middleHeadlandRow)
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
    centerBoundary:appendMany(self.middleHeadlandBlock:getFirstRow())
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
    -- Now we have three sides, need to close the polygon on the fourth side
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
    -- this will be the last up/down row of the center
    local lastCenterRow = rows[1]
    -- and we also use it to assemble the last, fourth side of the boundary around the center
    local fourthSide = lastCenterRow:clone()
    local intersections = fourthSide:getIntersections(centerBoundary)
    local startIs, endIs = intersections[1], intersections[#intersections]
    cg.addDebugPoint(startIs.is, 'start' .. #intersections)
    cg.addDebugPoint(endIs.is, 'end')
    if startIs.ixB > endIs.ixB then
        startIs, endIs = endIs, startIs
    end
    if startIs.ixA < endIs.ixA then
        fourthSide:cutEndAtIx(endIs.ixA)
        fourthSide:cutStartAtIx(startIs.ixA + 1)
        fourthSide:reverse()
    else
        fourthSide:cutEndAtIx(startIs.ixA)
        fourthSide:cutStartAtIx(endIs.ixA + 1)
    end
    centerBoundary:cutEndAtIx(endIs.ixB)
    centerBoundary:cutStartAtIx(startIs.ixB + 1)
    fourthSide:prepend(endIs.is)
    fourthSide:append(startIs.is)
    centerBoundary:appendMany(fourthSide)
    centerBoundary:calculateProperties()
    cg.addDebugPolyline(centerBoundary, {0, 0, 1, 1})
    return centerBoundary, lastCenterRow
end

---@class cg.FieldworkCourseTwoSided : cg.FieldworkCourse
cg.FieldworkCourseTwoSided = FieldworkCourseTwoSided
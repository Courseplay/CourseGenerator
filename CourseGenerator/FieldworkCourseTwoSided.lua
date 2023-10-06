--- Not the best name for it, but this is a fieldwork course where the headland is not
--- going around the field boundary, only two, opposite sides, think about a long
--- horizontal rectangle, the headlands would be on the left and right side of the
--- field only. Here an example starting on the left side:
--  , ,-, ,-----------------------------------------------------------,
--  | | | | ,---------------------------------------------------, ,-, |
--  | | | | '-------------------------------------------------, | | | |
--  | | | | ,-------------------------------------------------' | | | |
--  | | | | '-------------------------------------------------, | | | |
--  '-' '-' --------------------------------------------------' '-' '-'

---@class FieldworkCourseTwoSided : cg.FieldworkCourse
local FieldworkCourseTwoSided = CpObject(cg.FieldworkCourse)

function FieldworkCourseTwoSided:init(context)
    self.logger = cg.Logger('FieldworkCourseTwoSided')
    self:_setContext(context)
    self.headlandPath = cg.Polyline()
    self.circledIslands = {}

    -- this is the side where we start working, generate here headlands parallel to the field edge
    self.startHeadlandBlock = self:_createBlock(1, self.context.baselineEdge, self.virtualHeadland, self.context.nHeadlands)
    if self.startHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError('Can\'t generate headlands on start side for this field with the current settings')
        return
    end
    local startEntry = self:_getClosestEntry(self.startHeadlandBlock, self.context.startLocation)
    self.startHeadlandBlock:finalize(startEntry)

    -- find the opposite end of the field ...
    local center = self.boundary:getCenter()
    local oppositeBaselineLocation = center - (self.startHeadlandBlock:getRows()[1]:getMiddle() - center)
    -- ... and generate headlands over there too
    self.endHeadlandBlock = self:_createBlock(3, oppositeBaselineLocation, self.virtualHeadland, self.context.nHeadlands)
    if self.endHeadlandBlock:getNumberOfRows() == 0 then
        self.context:addError('Can\'t generate headlands on ending side for this field with the current settings')
        return
    end
    local startHeadlandBlockExit = self.startHeadlandBlock:getExit(startEntry)
    self.endHeadlandBlock:finalize(self:_getClosestEntry(self.startHeadlandBlock, startHeadlandBlockExit))
    self.logger:debug('Created start block with %d rows, end block with %d rows.',
            self.startHeadlandBlock:getNumberOfRows(), self.endHeadlandBlock:getNumberOfRows())
    -- now fill in the space between the headlands with rows parallel to the edge between the start and end
    self.centerBlock = self:_createBlock(2, startHeadlandBlockExit, self.virtualHeadland, 1)
    self.centerBlock:finalize(self:_getClosestEntry(self.centerBlock, startHeadlandBlockExit))
end

---@return cg.Polyline
function FieldworkCourseTwoSided:getHeadlandPath()
    local headlandPath = cg.Polyline()
    for _, r in ipairs(self.startHeadlandBlock:getRows()) do
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
    local centerPath = cg.Polyline()
    for _, r in ipairs(self.centerBlock:getRows()) do
        centerPath:appendMany(r)
    end
    return centerPath
end

---@param baselineLocation cg.Vector
---@param boundary cg.Headland
---@return cg.Block
function FieldworkCourseTwoSided:_createBlock(blockId, baselineLocation, boundary, nRows)
    local rows = cg.CurvedPathHelper.generateCurvedUpDownRows(boundary:getPolygon(), baselineLocation,
            self.context.workingWidth, self.context.turningRadius, nRows)
    local block = cg.Block(cg.RowPatternAlternatingFirstRowEntryOnly(), blockId)
    block:addRows(self:_cutAtBoundary(rows, boundary))
    return block
end

function FieldworkCourseTwoSided:_cutAtBoundary(rows, boundary)
    local cutRows = {}
    for i, row in ipairs(rows) do
        local sections = row:split(boundary, {}, true)
        if #sections == 1 then
            table.insert(cutRows, sections[1])
            cg.addDebugPolyline(row, {0, 1, 0, 0.3})
        elseif #sections > 1 then
            cg.addDebugPolyline(row, {1, 1, 0, 0.3})
        else
            cg.addDebugPolyline(row, {1, 0, 0, 0.3})
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

---@class cg.FieldworkCourseTwoSided : cg.FieldworkCourse
cg.FieldworkCourseTwoSided = FieldworkCourseTwoSided
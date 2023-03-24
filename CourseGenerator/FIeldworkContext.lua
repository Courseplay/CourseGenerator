--- A context with all parameters and constraints for a fieldwork course
--- to generate
local FieldworkContext = CpObject()

---@param field cg.Field
---@param workingWidth number working width
---@param turningRadius number minimum turning radius of the equipment
---@param nHeadlands number of headland passes
function FieldworkContext:init(field, workingWidth, turningRadius, nHeadlands)
    self.field = field
    self.workingWidth = workingWidth
    self.turningRadius = turningRadius
    self.nHeadlands = nHeadlands
    self.nHeadlandsWithRoundCorners = 0
    self.nIslandHeadlands = 1
    self.fieldCornerRadius = 0
    self.clockwise = true
end

---@param nHeadlands number of headlands total.
function FieldworkContext:setHeadlands(nHeadlands)
    self.nHeadlands = math.max(0, nHeadlands)
    return self
end

---@param nHeadlandsWithRoundCorners number of headlands that should have their corners rounded to the turning radius.
function FieldworkContext:setHeadlandsWithRoundCorners(nHeadlandsWithRoundCorners)
    self.nHeadlandsWithRoundCorners = math.min(self.nHeadlands, nHeadlandsWithRoundCorners)
    return self
end

---@param nIslandHeadlands number of headlands to generate around field islands
function FieldworkContext:setIslandHeadlands(nIslandHeadlands)
    self.nIslandHeadlands = nIslandHeadlands
    return self
end

---@param fieldCornerRadius number if a field has a corner under this radius, we'll sharpen it
function FieldworkContext:setFieldCornerRadius(fieldCornerRadius)
    self.fieldCornerRadius = fieldCornerRadius
end

---@param bypass boolean if true, the course will go around islands
function FieldworkContext:setBypassIslands(bypass)
   self.bypassIslands = bypass
end

---@param sharpen boolean if true, sharpen the corners of the headlands which are not rounded
function FieldworkContext:setSharpenCorners(sharpen)
    self.sharpenCorners = sharpen
end

---@param clockwise boolean generate headlands in the clockwise direction if true, counterclockwise if false
function FieldworkContext:setHeadlandClockwise(clockwise)
    self.headlandClockwise = clockwise
end

--- The (approximate) location where we want to start working on the headland when progressing inwards.
function FieldworkContext:setStartLocation(x, y)
    self.startLocation = cg.Vector(x, y)
end

--- Should the angle of rows determined automatically?
function FieldworkContext:setAutoRowAngle(auto)
    self.autoRowAngle = auto
end

--- Angle of the up/down rows when not automatically selected
function FieldworkContext:setRowAngle(rowAngle)
    self.rowAngle = rowAngle
end

--- Distribute rows evenly, so the distance between them may be less than the working width,
--- or should the last row absorb all the difference, so only the last row is narrower than
--- the working width
function FieldworkContext:setEvenRowDistribution(evenRowDistribution)
    self.evenRowDistribution = evenRowDistribution
end

---@class cg.FieldworkContext
cg.FieldworkContext = FieldworkContext
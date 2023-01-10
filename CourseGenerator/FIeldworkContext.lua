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
---@class cg.FieldworkContext
cg.FieldworkContext = FieldworkContext
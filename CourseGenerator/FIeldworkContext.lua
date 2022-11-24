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
end

---@param type string smooth, round or sharp
function FieldworkContext:setCorners(type)
    self.cornerType = type
    return self
end

---@class cg.FieldworkContext
cg.FieldworkContext = FieldworkContext
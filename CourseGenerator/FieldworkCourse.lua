local FieldworkCourse = CpObject()

---@param field cg.Field
function FieldworkCourse:init(field, width)
    self.field = field
    self.width = width
end

function FieldworkCourse:generateHeadlands(nHeadlandPasses)
    self.headlands = {}
    -- outermost headland is offset from the field boundary by half width
    self.headlands[1] = cg.Headland(self.field:getBoundary(), self.width / 2)
    for i = 2, nHeadlandPasses do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), self.width)
    end
end

function FieldworkCourse:getHeadlands()
    return self.headlands
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse
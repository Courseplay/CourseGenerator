local FieldworkCourse = CpObject()

---@param field cg.Field
function FieldworkCourse:init(field, width)
    self.field = field
    self.width = width
end

function FieldworkCourse:debug(...)
   cg.debug('FieldworkCourse: ' .. string.format(...))
end

function FieldworkCourse:generateHeadlandsFromOutside(nHeadlandPasses, minimumRadius)
    self:debug('generating %d headlands from the outside, min radius %.1f', nHeadlandPasses, minimumRadius)
    self.headlands = {}
    -- outermost headland is offset from the field boundary by half width
    self.headlands[1] = cg.Headland(self.field:getBoundary(), self.width / 2, false, minimumRadius)
    for i = 2, nHeadlandPasses do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), self.width, false, minimumRadius)
    end
end

function FieldworkCourse:generateHeadlandsFromInside(nHeadlandPasses, minimumRadius)
    self:debug('generating %d headlands from the inside, min radius %.1f', nHeadlandPasses, minimumRadius)
    self.headlands = {}
    -- start with the innermost headland
    self.headlands[nHeadlandPasses] = cg.Headland(self.field:getBoundary(), (nHeadlandPasses - 0.5) * self.width, false, minimumRadius)
    for i = nHeadlandPasses - 1, 1, -1 do
        self.headlands[i] = cg.Headland(self.headlands[i + 1]:getPolygon(), self.width, true, minimumRadius)
    end
end

function FieldworkCourse:getHeadlands()
    return self.headlands
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse
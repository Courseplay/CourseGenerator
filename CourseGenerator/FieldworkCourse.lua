local FieldworkCourse = CpObject()

---@param context cg.FieldworkContext
function FieldworkCourse:init(context)
    self.context = context
    ---@type cg.Polygon
    self.boundary = context.field:getBoundary():clone()
    if context.cornerType == 'sharp' then
        self:debug('sharpening field boundary corners')
        self.boundary:ensureMinimumRadius(self.context.turningRadius, true)
    end
end

function FieldworkCourse:debug(...)
   cg.debug('FieldworkCourse: ' .. string.format(...))
end

function FieldworkCourse:generateHeadlands()
    if self.context.cornerType == 'round' then
        self:generateHeadlandsFromInside()
    else
        self:generateHeadlandsFromOutside()
    end
end

function FieldworkCourse:generateHeadlandsFromOutside()
    local function adjustCorners(headland)
        if self.context.cornerType == 'round' then
            headland:roundCorners(self.context.turningRadius)
        elseif self.context.cornerType == 'sharp' then
            --headland:sharpenCorners(self.context.turningRadius)
        end
    end

    self:debug('generating %d headlands from the outside, min radius %.1f', self.context.nHeadlands, self.context.turningRadius)
    self.headlands = {}
    -- outermost headland is offset from the field boundary by half width
    self.headlands[1] = cg.Headland(self.boundary, self.context.workingWidth / 2, false, self.context.turningRadius)
    adjustCorners(self.headlands[1])
    for i = 2, self.context.nHeadlands do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), self.context.workingWidth, false, self.context.turningRadius)
        adjustCorners(self.headlands[i])
    end
end

function FieldworkCourse:generateHeadlandsFromInside()
    self:debug('generating %d headlands from the inside, min radius %.1f', self.context.nHeadlands, self.context.turningRadius)
    self.headlands = {}
    -- start with the innermost headland
    self.headlands[self.context.nHeadlands] = cg.Headland(self.boundary, (self.context.nHeadlands - 0.5) * self.context.workingWidth, false)
    self.headlands[self.context.nHeadlands]:roundCorners(self.context.turningRadius)
    for i = self.context.nHeadlands - 1, 1, -1 do
        self.headlands[i] = cg.Headland(self.headlands[i + 1]:getPolygon(), self.context.workingWidth, true)
        self.headlands[self.context.nHeadlands]:roundCorners(self.context.turningRadius)
    end
end

function FieldworkCourse:getHeadlands()
    return self.headlands
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse
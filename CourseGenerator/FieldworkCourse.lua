local FieldworkCourse = CpObject()

---@param context cg.FieldworkContext
function FieldworkCourse:init(context)
    self.logger = cg.Logger('FieldworkCourse')
    self.context = context
    ---@type cg.Polygon
    self.boundary = context.field:getBoundary():clone()
    if self.context.fieldCornerRadius > 0 then
        self.logger:debug('sharpening field boundary corners')
        self.boundary:ensureMinimumRadius(self.context.fieldCornerRadius, true)
    end
end

------------------------------------------------------------------------------------------------------------------------
--- Headlands
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:generateHeadlands()
    self.headlands = {}
    self.logger:debug('generating %d headlands with round corners, then %d with sharp corners',
            self.context.nHeadlandsWithRoundCorners, self.context.nHeadlands)
    if self.context.nHeadlandsWithRoundCorners > 0 then
        self:generateHeadlandsFromInside()
        if self.context.nHeadlands > self.context.nHeadlandsWithRoundCorners then
            self:generateHeadlandsFromOutside(self.boundary,
                    (self.context.nHeadlandsWithRoundCorners + 0.5) * self.context.workingWidth,
                    #self.headlands + 1)
        end
    elseif self.context.nHeadlands > 0 then
        self:generateHeadlandsFromOutside(self.boundary, self.context.workingWidth / 2, 1)
    end
    self:generateHeadlandsAroundIslands()
    for _, h in ipairs(self.headlands) do
        h:bypassIslands(self.context.field:getIslands())
    end
end

---@param boundary Polygon field boundary or other headland to start the generation from
---@param firstHeadlandWidth number width of the outermost headland to generate, if the boundary is the field boundary,
--- it will usually be the half working width, if the boundary is another headland, the full working width
---@param startIx number index of the first headland to generate
function FieldworkCourse:generateHeadlandsFromOutside(boundary, firstHeadlandWidth, startIx)

    self.logger:debug('generating %d sharp headlands from the outside, min radius %.1f',
            self.context.nHeadlands - startIx, self.context.turningRadius)
    -- outermost headland is offset from the field boundary by half width
    self.headlands[startIx] = cg.Headland(boundary, startIx, firstHeadlandWidth, false, self.context.turningRadius)
    self.headlands[startIx]:sharpenCorners(self.context.turningRadius)
    for i = startIx + 1, self.context.nHeadlands do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), i, self.context.workingWidth, false, self.context.turningRadius)
        self.headlands[i]:sharpenCorners(self.context.turningRadius)
    end
end

function FieldworkCourse:generateHeadlandsFromInside()
    self.logger:debug('generating %d headlands with round corners, min radius %.1f',
            self.context.nHeadlandsWithRoundCorners, self.context.turningRadius)
    -- start with the innermost headland
    self.headlands[self.context.nHeadlandsWithRoundCorners] = cg.Headland(self.boundary, self.context.nHeadlandsWithRoundCorners,
            (self.context.nHeadlandsWithRoundCorners - 0.5) * self.context.workingWidth, false)
    self.headlands[self.context.nHeadlandsWithRoundCorners]:roundCorners(self.context.turningRadius)
    for i = self.context.nHeadlandsWithRoundCorners - 1, 1, -1 do
        self.headlands[i] = cg.Headland(self.headlands[i + 1]:getPolygon(), i, self.context.workingWidth, true)
        self.headlands[i]:roundCorners(self.context.turningRadius)
    end
end

function FieldworkCourse:getHeadlands()
    return self.headlands
end

------------------------------------------------------------------------------------------------------------------------
--- Islands
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:generateHeadlandsAroundIslands()
    for _, island in pairs(self.context.field:getIslands()) do
        island:generateHeadlands(self.context)
    end
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse
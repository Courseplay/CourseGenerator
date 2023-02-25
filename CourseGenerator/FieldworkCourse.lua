local FieldworkCourse = CpObject()

---@param context cg.FieldworkContext
function FieldworkCourse:init(context)
    self.logger = cg.Logger('FieldworkCourse')
    self:_setContext(context)
end

------------------------------------------------------------------------------------------------------------------------
--- Headlands
------------------------------------------------------------------------------------------------------------------------
--- Generate the headlands based on the current context or the context passed in here
---@param context cg.FieldworkContext if defined, set it as current context before generating the headlands
function FieldworkCourse:generateHeadlands(context)
    if context then self:_setContext(context) end
    self.headlands = {}
    self.logger:debug('generating %d headlands with round corners, then %d with sharp corners',
            self.nHeadlandsWithRoundCorners, self.nHeadlands - self.nHeadlandsWithRoundCorners)
    if self.nHeadlandsWithRoundCorners > 0 then
        self:generateHeadlandsFromInside()
        if self.nHeadlands > self.nHeadlandsWithRoundCorners and #self.headlands < self.nHeadlands then
            self:generateHeadlandsFromOutside(self.boundary,
                    (self.nHeadlandsWithRoundCorners + 0.5) * self.context.workingWidth,
                    #self.headlands + 1)
        end
    elseif self.nHeadlands > 0 then
        self:generateHeadlandsFromOutside(self.boundary, self.context.workingWidth / 2, 1)
    end
    self:connectHeadlands()
    if self.context.bypassIslands then
        self:generateHeadlandsAroundIslands()
        --- Remember the islands we circled already, as even if multiple tracks cross it, we only want to
        --- circle once.
        self.circledIslands = {}
        for _, h in ipairs(self.headlands) do
            for _, island in pairs(self.context.field:getIslands()) do
                self.circledIslands[island] = h:bypassIsland(island, not self.circledIslands[island])
            end
        end
    end
end

---@param boundary Polygon field boundary or other headland to start the generation from
---@param firstHeadlandWidth number width of the outermost headland to generate, if the boundary is the field boundary,
--- it will usually be the half working width, if the boundary is another headland, the full working width
---@param startIx number index of the first headland to generate
function FieldworkCourse:generateHeadlandsFromOutside(boundary, firstHeadlandWidth, startIx)

    self.logger:debug('generating %d sharp headlands from the outside, min radius %.1f',
            self.nHeadlands - startIx + 1, self.context.turningRadius)
    -- outermost headland is offset from the field boundary by half width
    self.headlands[startIx] = cg.Headland(boundary, startIx, firstHeadlandWidth, false, self.context.turningRadius)
    if not self.headlands[startIx]:isValid() then
        self:_removeHeadland(startIx)
        return
    end
    if self.context.sharpenCorners then
        self.headlands[startIx]:sharpenCorners(self.context.turningRadius)
    end
    for i = startIx + 1, self.nHeadlands do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), i, self.context.workingWidth, false, self.context.turningRadius)
        if self.headlands[i]:isValid() then
            if self.context.sharpenCorners then
                self.headlands[i]:sharpenCorners(self.context.turningRadius)
            end
        else
            self:_removeHeadland(i)
            break
        end
    end
end

function FieldworkCourse:generateHeadlandsFromInside()
    self.logger:debug('generating %d headlands with round corners, min radius %.1f',
            self.nHeadlandsWithRoundCorners, self.context.turningRadius)
    -- start with the innermost headland, try until it can fit in the field (as the required number of
    -- headlands may be more than what actually fits into the field)
    while self.nHeadlandsWithRoundCorners > 0 do
        self.headlands[self.nHeadlandsWithRoundCorners] = cg.Headland(self.boundary, self.nHeadlandsWithRoundCorners,
                (self.nHeadlandsWithRoundCorners - 0.5) * self.context.workingWidth, false)
        if self.headlands[self.nHeadlandsWithRoundCorners]:isValid() then
            self.headlands[self.nHeadlandsWithRoundCorners]:roundCorners(self.context.turningRadius)
            break
        else
            self:_removeHeadland(self.nHeadlandsWithRoundCorners)
            self.logger:warning('no room for innermost headland, reducing headlands to %d, rounded %d',
                    self.nHeadlands, self.nHeadlandsWithRoundCorners)
        end
    end
    for i = self.nHeadlandsWithRoundCorners - 1, 1, -1 do
        self.headlands[i] = cg.Headland(self.headlands[i + 1]:getPolygon(), i, self.context.workingWidth, true)
        self.headlands[i]:roundCorners(self.context.turningRadius)
    end
end

function FieldworkCourse:connectHeadlands()
    local closestVertex = self.headlands[1]:getPolygon():findClosestVertex(self.context.startLocation)
    self.headlands[1]:connectTo(self.headlands[2], closestVertex.ix)
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

------------------------------------------------------------------------------------------------------------------------
--- Private functions
------------------------------------------------------------------------------------------------------------------------
function FieldworkCourse:_setContext(context)
    self.context = context
    self.nHeadlands = self.context.nHeadlands
    self.nHeadlandsWithRoundCorners = self.context.nHeadlandsWithRoundCorners
    ---@type cg.Polygon
    self.boundary = context.field:getBoundary():clone()
    if self.boundary:isClockwise() ~= self.context.headlandClockwise then
        -- all headlands are generated in the same direction as the field boundary,
        -- so if it does not match the required cw/ccw, reverse it
        self.boundary:reverse()
    end
    if self.context.fieldCornerRadius > 0 then
        self.logger:debug('sharpening field boundary corners')
        self.boundary:ensureMinimumRadius(self.context.fieldCornerRadius, true)
    end
end

function FieldworkCourse:_removeHeadland(i)
    self.headlands[i] = nil
    self.nHeadlands = i - 1
    self.nHeadlandsWithRoundCorners = math.min(self.nHeadlands, self.nHeadlandsWithRoundCorners)
    self.logger:error('could not generate headland %d, course has %d headlands, %d rounded',
            i, self.nHeadlands, self.nHeadlandsWithRoundCorners)
end

---@class cg.FieldworkCourse
cg.FieldworkCourse = FieldworkCourse
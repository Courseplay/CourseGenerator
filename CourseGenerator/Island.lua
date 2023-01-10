local Island = CpObject()

---@class cg.Island
cg.Island = Island

-- grid spacing used for island detection. Consequently, this will be the grid spacing
-- of the island points.
Island.gridSpacing = 1

function Island:init(id, perimeterPoints)
    self.boundary = cg.Polygon()
    self.id = id
    self.logger = cg.Logger('Island ' .. self.id)
    self.headlands = {}
    self.circled = false
    self:createFromPerimeterPoints(perimeterPoints)
end

------------------------------------------------------------------------------------------------------------------------
-- Functions to create an island as a polygon from a bunch of points (raster -> vector)
------------------------------------------------------------------------------------------------------------------------
local function getNumberOfIslandNeighbors(point, islandPoints, gridSpacing)
    local nNeighbors = 0
    for _, v in ipairs(islandPoints) do
        local d = (point - v):length()
        -- 1.5 is around sqrt( 2 ), to find diagonal neighbors too
        if d < 1.5 * gridSpacing then
            nNeighbors = nNeighbors + 1
        end
    end
    return nNeighbors
end

local function findPointWithinDistance(point, otherPoints, d)
    for i, other in ipairs(otherPoints) do
        if (point - other ):length() < d then
            return i, other
        end
    end
    return nil, nil
end

function Island.getIslandPerimeterPoints(islandPoints)
    local perimeterPoints = {}
    for _, v in ipairs(islandPoints) do
        -- a vertex on the perimeter has at least two non-island neighbors (out of the possible
        -- 8 neighbors at most 6 can be island vertices).
        if getNumberOfIslandNeighbors(v, islandPoints, Island.gridSpacing) <= 6 then
            table.insert(perimeterPoints, v)
        end
    end
    return perimeterPoints
end

-- Accepts a list of perimeter points (vectors) and creates an island
-- polygon. The list may define multiple islands, in that
-- case, it creates one island, removing the vertices used 
-- for that island from perimeterPoints and returns the
-- remaining vertices.
---@param perimeterPoints cg.Vector[]
function Island:createFromPerimeterPoints(perimeterPoints)
    if #perimeterPoints < 1 then return perimeterPoints end
    local currentPoint = perimeterPoints[1]
    self.boundary:append(currentPoint)
    table.remove(perimeterPoints, 1)
    local ix, otherPoint
    otherPoint = currentPoint
    while otherPoint do
        -- find the next vertex, try closest first. 3.01 so it is guaranteed to be closer than 3 * gridSpacing
        for _, d in ipairs({self.gridSpacing * 1.01, 1.5 * self.gridSpacing, 2.3 * self.gridSpacing, 3.01 * self.gridSpacing}) do
            ix, otherPoint = findPointWithinDistance(currentPoint, perimeterPoints, d)
            if ix then
                self.boundary:append(otherPoint)
                table.remove(perimeterPoints, ix)
                -- next vertex found, continue from that vertex
                currentPoint = otherPoint
                break
            end
        end
    end
    self.boundary:calculateProperties()
    --self.boundary:space( math.rad( 20 ), 5 )
    --self.width = self.boundary.boundingBox.maxX - self.boundary.boundingBox.minX
    --self.height = self.boundary.boundingBox.maxY - self.boundary.boundingBox.minY
    --CourseGenerator.debug( "Island #%d with %d vertices created, %.0fx%0.f, area %.0f", self.id, #self.boundary, self.width, self.height, self.boundary.area )
end

---@return cg.Polygon
function Island:getBoundary()
    return self.boundary
end

function Island:generateHeadlands(context)
    self.context = context
    self.logger:debug('generating %d headlands', self.context.nIslandHeadlands, self.context.turningRadius)
    self.headlands = {}
    -- outermost headland is offset from the field boundary by half width
    self.headlands[1] = cg.Headland(self.boundary, 1, self.context.workingWidth / 2, true, self.context.turningRadius)
    for i = 2, self.context.nIslandHeadlands do
        self.headlands[i] = cg.Headland(self.headlands[i - 1]:getPolygon(), i - 1, self.context.workingWidth, true, self.context.turningRadius)
    end
end

function Island:getHeadlands()
    return self.headlands
end

------------------------------------------------------------------------------------------------------------------------
-- TODO: Find islands in the game.
------------------------------------------------------------------------------------------------------------------------
local function generateGridForPolygon( polygon, gridSpacingHint )
    local grid = {}
    -- map[ row ][ column ] maps the row/column address of the grid to a linear
    -- array index in the grid.
    grid.map = {}
    polygon.boundingBox = polygon:getBoundingBox()
    polygon:calculateData()
    -- this will make sure that the grid will have approximately 64^2 = 4096 points
    -- TODO: probably need to take the aspect ratio into account for odd shaped
    -- (long and narrow) fields
    -- But don't go below a certain limit as that would drive too close to the fruit
    -- for this limit, use a fraction to reduce the chance of ending up right on the field edge (assuming fields
    -- are drawn using integer sizes) as that may result in a row or two missing in the grid
    local gridSpacing = gridSpacingHint or math.max( 4.071, math.sqrt( polygon.area ) / 64 )
    local horizontalLines = CourseGenerator.generateParallelTracks( polygon, {}, gridSpacing, gridSpacing / 2 )
    if not horizontalLines then return grid end
    -- we'll need this when trying to find the array index from the
    -- grid coordinates. All of these lines are the same length and start
    -- at the same x
    grid.width = math.floor( horizontalLines[ 1 ].from.x / gridSpacing )
    grid.height = #horizontalLines
    -- now, add the grid points
    local margin = gridSpacing / 2
    for row, line in ipairs( horizontalLines ) do
        local column = 0
        grid.map[ row ] = {}
        for x = line.from.x, line.to.x, gridSpacing do
            column = column + 1
            for j = 1, #line.intersections, 2 do
                if line.intersections[ j + 1 ] then
                    if x > line.intersections[ j ].x + margin and x < line.intersections[ j + 1 ].x - margin then
                        local y = line.from.y
                        -- check an area bigger than the self.gridSpacing to make sure the path is not too close to the fruit
                        table.insert( grid, { x = x, y = y, column = column, row = row })
                        grid.map[ row ][ column ] = #grid
                    end
                end
            end
        end
    end
    return grid, gridSpacing
end

function Island.findIslands( polygon )
    local grid, _ = generateGridForPolygon( polygon, Island.gridSpacing )
    local islandVertices = {}
    for _, row in ipairs(grid.map) do
        for _, index in pairs(row) do
            local isOnField, _ = FSDensityMapUtil.getFieldDataAtWorldPosition(grid[index].x, 0, -grid[index].y)
            if not isOnField then
                -- add a vertex only if it is far enough from the field boundary
                -- to filter false positives around the field boundary
                local _, d = polygon:getClosestPointIndex(grid[index])
                -- TODO: should calculate the closest distance to polygon edge, not
                -- the vertices. This may miss an island close enough to the field boundary
                if d > 8 * Island.gridSpacing then
                    table.insert(islandVertices, grid[index])
                end
            end
        end
    end
    return islandVertices
end
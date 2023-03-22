---@class NewCourseGenerator
NewCourseGenerator = {}

--- Tunable parameters
-- The maximum length of a polyline/polygon edge. This means no waypoints of the
-- generated course will be further than this.
NewCourseGenerator.cMaxEdgeLength = 5
-- The minimum length of a polyline/polygon edge. No waypoints will be closer than this.
-- If a vertex is closer than cMinEdgeLength to the next, it is removed
NewCourseGenerator.cMinEdgeLength = 0.5
-- When ensuring maxEdgeLength and adding a new vertex and the direction change at
-- the previous vertex is less than this, the new vertex will be offset from the original
-- edge so the result is an arc. Over this angle, we won't offset, so corners are kept sharp.
NewCourseGenerator.cMaxDeltaAngleForMaxEdgeLength = math.rad(30)
-- Maximum cross track error we tolerate when a vehicle follows a path. This is used to
-- find corners which the vehicle can't make due to its turning radius without being more than
-- cMaxCrossTrackError meters from the vertex in the corner.
NewCourseGenerator.cMaxCrossTrackError = 0.3
-- The delta angle above which smoothing kicks in. No smoothing around vertices with a delta
-- angle below this
NewCourseGenerator.cMinSmoothingAngle = math.rad(25)
-- Minimum radius in meters where a change to the next headland is allowed. This is to ensure that
-- we only change lanes on relatively straight sections of the headland (not around corners)
NewCourseGenerator.headlandChangeMinRadius = 20
-- No headland change allowed if there is a corner ahead within this distance in meters
NewCourseGenerator.headlandChangeMinDistanceToCorner = 20
-- No headland change allowed if there is a corner behind within this distance in meters
NewCourseGenerator.headlandChangeMinDistanceFromCorner = 10

-- when enabled, will print a lot of information
NewCourseGenerator.traceEnabled = false

--- Debug print, will either just call print when running standalone
--  or use the CP debug channel when running in the game.
function NewCourseGenerator.debug(...)
    if NewCourseGenerator.isRunningInGame() then
        CpUtil.debugVehicle(CpDebug.DBG_COURSES, g_currentMission.controlledVehicle, ...)
    else
        print(string.format(...))
        io.stdout:flush()
    end
end

function NewCourseGenerator.info(...)
    if NewCourseGenerator.isRunningInGame() then
        -- TODO: debug channel (info)
        CpUtil.info(...)
    else
        print(string.format(...))
        io.stdout:flush()
    end
end

function NewCourseGenerator.trace(...)
    if not NewCourseGenerator.traceEnabled then return end
    if NewCourseGenerator.isRunningInGame() then
        CpUtil.debugVehicle(CpDebug.DBG_COURSES, g_currentMission.controlledVehicle, ...)
    else
        print(string.format(...))
        io.stdout:flush()
    end
end

function NewCourseGenerator.enableTrace()
    NewCourseGenerator.traceEnabled = true
end

function NewCourseGenerator.disableTrace()
    NewCourseGenerator.traceEnabled = false
end

--- Add a point to the list of debug points we want to show on the test display
---@param v cg.Vector
function NewCourseGenerator.addDebugPoint(v)
    if not NewCourseGenerator.debugPoints then
        NewCourseGenerator.debugPoints = {}
    end
    table.insert(NewCourseGenerator.debugPoints, v:clone())
end

--- Return true when running in the game
-- used by file and log functions to determine how exactly to do things,
-- for example, io.flush is not available from within the game.
--
function NewCourseGenerator.isRunningInGame()
    return g_currentMission ~= nil and not g_currentMission.mock;
end

---@class cg
cg = NewCourseGenerator
---@class NewCourseGenerator
NewCourseGenerator = {}

--- Tunable parameters
-- The maximum length of a polyline/polygon edge. This means no waypoints of the
-- generated course will be further than this.
NewCourseGenerator.cMaxEdgeLength = 5
-- When ensuring maxEdgeLength and adding a new vertex and the direction change at
-- the previous vertex is less than this, the new vertex will be offset from the original
-- edge so the result is an arc. Over this angle, we won't offset, so corners are kept sharp.
NewCourseGenerator.cMaxDeltaAngleForMaxEdgeLength = math.rad(45)

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

--- Return true when running in the game
-- used by file and log functions to determine how exactly to do things,
-- for example, io.flush is not available from within the game.
--
function NewCourseGenerator.isRunningInGame()
    return g_currentMission ~= nil and not g_currentMission.mock;
end

---@class cg
cg = NewCourseGenerator
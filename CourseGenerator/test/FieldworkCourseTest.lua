require('include')
profiler = require('profile')

lu.EPS = 0.01
local fields = cg.Field.loadSavedFields('../../fields/Coldborough.xml')
local field = fields[2]
local workingWidth = 8
local turningRadius = 6
local nHeadlands = 4
local context = cg.FieldworkContext(field, workingWidth, turningRadius, nHeadlands)
local fieldworkCourse = cg.FieldworkCourse(context)
--profiler.start()
fieldworkCourse:generateHeadlands()
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateCenter()
print(profiler.report(40))
context:setBypassIslands(true)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateCenter()
context:setHeadlandsWithRoundCorners(1)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateCenter()
context:setHeadlandsWithRoundCorners(nHeadlands)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateCenter()
nHeadlands = 5
context:setHeadlands(nHeadlands)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateCenter()

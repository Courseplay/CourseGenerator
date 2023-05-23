require('include')
lu.EPS = 0.01
local fields = cg.Field.loadSavedFields('../../fields/Coldborough.xml')
local field = fields[2]
local workingWidth = 8
local turningRadius = 6
local nHeadlands = 4
local context = cg.FieldworkContext(field, workingWidth, turningRadius, nHeadlands)
local fieldworkCourse = cg.FieldworkCourse(context)
fieldworkCourse:generateHeadlands()
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateUpDownRows()
context:setBypassIslands(true)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateUpDownRows()
context:setHeadlandsWithRoundCorners(1)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateUpDownRows()
context:setHeadlandsWithRoundCorners(nHeadlands)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateUpDownRows()
nHeadlands = 5
context:setHeadlands(nHeadlands)
fieldworkCourse:generateHeadlands(context)
lu.assertEquals(#fieldworkCourse:getHeadlands(), nHeadlands)
fieldworkCourse:generateUpDownRows()

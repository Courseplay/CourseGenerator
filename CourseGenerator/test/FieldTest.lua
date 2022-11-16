require('include')

local fields = cg.Field.loadSavedFields('../../fields/Coldborough.xml')
lu.assertEquals(#fields, 9)
lu.assertEquals(#fields[8].boundary, 135)
local field = fields[8]
local center = field:getCenter()
lu.assertAlmostEquals(center.x, 380.8, 0.1)
lu.assertAlmostEquals(center.y, 31.14, 0.1)
local x1, y1, x2, y2 = field:getBoundingBox()
lu.assertAlmostEquals(x1, 307.15, 0.1)
lu.assertAlmostEquals(y1, -80.84, 0.1)
lu.assertAlmostEquals(x2, 452.84, 0.1)
lu.assertAlmostEquals(y2, 157.33, 0.1)

field:getBoundary():ensureMinimumRadius(5)

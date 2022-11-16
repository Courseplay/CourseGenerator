require('include')

-- epsilon for assertAlmostEquals
lu.EPS = 0.01

local v = cg.Vertex(0, 0)
v:calculateProperties(nil, cg.Vertex(1, 1))
lu.assertAlmostEquals(v:getEntryHeading(), math.pi / 4)
lu.assertAlmostEquals(v:getExitHeading(), math.pi / 4)
lu.assertIsNil(v:getEntryEdge())
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 1))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(1, 1), nil)
lu.assertAlmostEquals(v:getEntryHeading(), - 3 * math.pi / 4)
lu.assertAlmostEquals(v:getExitHeading(), - 3 * math.pi / 4)
lu.assertIsNil(v:getExitEdge())
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(1, 1, 0, 0))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, 0))
lu.assertAlmostEquals(v:getEntryHeading(), 0)
lu.assertAlmostEquals(v:getExitHeading(), 0)
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(-1, 0, 0, 0))
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 0))
lu.assertEquals(v:getRadius(), math.huge)

v = cg.Vertex(0, 0)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, 1))
lu.assertAlmostEquals(v:getEntryHeading(), 0)
lu.assertAlmostEquals(v:getExitHeading(), math.pi / 4)
v:getEntryEdge():assertAlmostEquals(cg.LineSegment(-1, 0, 0, 0))
v:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 1, 1))
lu.assertAlmostEquals(v:getRadius(), 1.84)
v:calculateProperties(cg.Vertex(-1, 0), cg.Vertex(1, -1))
lu.assertAlmostEquals(v:getRadius(), -1.84)

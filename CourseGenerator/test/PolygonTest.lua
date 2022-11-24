require('include')

local p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 1), cg.Vector(0, 2), cg.Vector(1, 2)})
local e = p:calculateEdges()
lu.assertEquals(e[1], cg.LineSegment(0, 0, 0, 1))
lu.assertEquals(e[2], cg.LineSegment(0, 1, 0, 2))
lu.assertEquals(e[3], cg.LineSegment(0, 2, 1, 2))
lu.assertEquals(e[4], cg.LineSegment(1, 2, 0, 0))

-- inside
p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0)})
local o = p:createOffset(cg.Vector(0, -1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(1, 1))
o[2]:assertAlmostEquals(cg.Vector(1, 4))
o[3]:assertAlmostEquals(cg.Vector(4, 4))
o[4]:assertAlmostEquals(cg.Vector(4, 1))

-- wrap around case
p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0), cg.Vector(4, 0)})
p:ensureMinimumEdgeLength(2)
lu.assertEquals(#p, 4)
p[4]:assertAlmostEquals(cg.Vector(5, 0))

-- outside, cut corner
p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0)})
o = p:createOffset(cg.Vector(0, 1), 1, false)
o[1]:assertAlmostEquals(cg.Vector(-1, 0))
o[2]:assertAlmostEquals(cg.Vector(-1, 5))
o[3]:assertAlmostEquals(cg.Vector(0, 6))
o[4]:assertAlmostEquals(cg.Vector(5, 6))
o[5]:assertAlmostEquals(cg.Vector(6, 5))
o[6]:assertAlmostEquals(cg.Vector(6, 0))
o[7]:assertAlmostEquals(cg.Vector(5, -1))
o[8]:assertAlmostEquals(cg.Vector(0, -1))

-- outside, preserve corner
p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0)})
o = p:createOffset(cg.Vector(0, 1), 1, true)
o[1]:assertAlmostEquals(cg.Vector(-1, -1))
o[2]:assertAlmostEquals(cg.Vector(-1, 6))
o[3]:assertAlmostEquals(cg.Vector(6, 6))
o[4]:assertAlmostEquals(cg.Vector(6, -1))
lu.assertIsTrue(p:isClockwise())

p = cg.Polygon({cg.Vector(0, 0), cg.Vector(0, 5), cg.Vector(5, 5), cg.Vector(5, 0), cg.Vector(0.3, 0), cg.Vector(0.1, 0)})
p:ensureMinimumEdgeLength(1)
p[1]:assertAlmostEquals(cg.Vector(0, 0))
p[2]:assertAlmostEquals(cg.Vector(0, 5))
p[3]:assertAlmostEquals(cg.Vector(5, 5))
p[4]:assertAlmostEquals(cg.Vector(5, 0))

-- wrap around
p = cg.Polygon({cg.Vector(5, 0), cg.Vector(5, 5), cg.Vector(0, 5), cg.Vector(0, 0)})
lu.assertIsFalse(p:isClockwise())
p:calculateProperties()
p[1]:getEntryEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))
p[1]:getExitEdge():assertAlmostEquals(cg.LineSegment(5, 0, 5, 5))
p[4]:getExitEdge():assertAlmostEquals(cg.LineSegment(0, 0, 5, 0))

-- point in polygon
p = cg.Polygon({cg.Vector(-10,-10), cg.Vector(10, -10), cg.Vector(10, 10), cg.Vector(-10, 10)})
lu.assertIsTrue(p:isInside(0, 0))
lu.assertIsTrue(p:isInside(5, 5))
lu.assertIsTrue(p:isInside(-5, -5))
lu.assertIsTrue(p:isInside(-10, -5))
lu.assertIsTrue(p:isInside(-9.99, -10))
lu.assertIsFalse(p:isInside(-9.99, 10))

lu.assertIsFalse(p:isInside(-10.01, -5))
lu.assertIsFalse(p:isInside(10.01, 50))

p = cg.Polygon({cg.Vector(-10, -10), cg.Vector(10, -10), cg.Vector(0, 0), cg.Vector(10, 10), cg.Vector(-10, 10)})

lu.assertIsFalse(p:isInside( 0, 0))
lu.assertIsFalse(p:isInside( 5, 5))
lu.assertIsTrue(p:isInside( -5, -5))
lu.assertIsTrue(p:isInside( -10, -5))
lu.assertIsFalse(p:isInside( -10, 10))

lu.assertIsFalse(p:isInside( 0.01, 0))
lu.assertIsFalse(p:isInside( 10, 0))
lu.assertIsFalse(p:isInside( 5, 2))
lu.assertIsFalse(p:isInside( 5, -2))
lu.assertIsFalse(p:isInside( -10.01, -5))
lu.assertIsFalse(p:isInside( 10.01, 50))

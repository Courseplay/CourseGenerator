package.path = package.path .. ";FS22_Courseplay/scripts/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/util/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/pathfinder/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/geometry/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/courseGenerator/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/courseGenerator/Geometry/?.lua"
package.path = package.path .. ";FS22_Courseplay/scripts/courseGenerator/Genetic/?.lua"
dofile('FS22_Courseplay/scripts/courseGenerator/test/require.lua')
require('AdjustableParameter')
require('ToggleParameter')
require('ListParameter')
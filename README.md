# Fieldwork Course Generator

The Fieldwork Course Generator is a route planner for farming equipment 
like tractors or harvesters to perform their fieldwork efficiently.

The Generator is part of Courseplay, a mod for the Farming 
Simulator game but it at has no dependency on the game API and can 
run independently of the game. 

This repository contains everything you need to test the 
Course Generator in a standalone Love2D environment. 

The Course Generator code is in the Courseplay repository, this is 
only the environment, so you'll need to clone the https://github.com/Courseplay/Courseplay_FS25 to
the FS25_Courseplay folder under the root of this repo.

The `fields` folder contains field definitions exported from many Farming Simulator maps. You can load those in this standalone tool
which will show you all fields of the map. You can select any of them, set the generator parameters and run the generator to 
test how each setting work.

To run in standalone mode, start a Windows terminal, change to the root directory of the cloned repo and run 

`.\love\love.exe . fields/<field file> <field number>`

to load a field file, focus on the field identified by the number and generate a course for that field. For instance:

`.\love\love.exe . fields/Goliszew.xml 50` 

loads the fields from the Goliszew map and generates the course for field 50.

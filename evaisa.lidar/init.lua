dofile("mods/evaisa.lidar/lib/timeofday.lua")
profiler = dofile("mods/evaisa.lidar/lib/profiler.lua")
local nxml = dofile("mods/evaisa.lidar/lib/nxml.lua")

ModRegisterAudioEventMappings( "mods/evaisa.lidar/GUIDs.txt" )
ModMaterialsFileAdd( "mods/evaisa.lidar/files/materials.xml" )

function OnMagicNumbersAndWorldSeedInitialized()

	--[[
	local biomes_content = ModTextFileGetContent("data/biome/_biomes_all.xml")

	local biomes_parsed = nxml.parse(biomes_content)
	for elem in biomes_parsed:each_child() do
		if (elem.name == "Biome") then
			local file_name = elem.attr.biome_filename
			if(file_name)then
				local biome_content = ModTextFileGetContent(file_name)
				local biome_parsed = nxml.parse(biome_content)
				for elem2 in biome_parsed:each_child() do
					if(elem2.name == "Topology")then
						elem2.attr.fog_of_war_type="HEAVY_NO_CLEAR"
					end
				end
				local modified = tostring(biome_parsed)

				ModTextFileSetContent(file_name, modified)
			end
		end
	end
	]]
	

end

function OnPlayerSpawned( player_entity ) 
	local x, y = EntityGetTransform( player_entity )
	EntityLoad( "mods/evaisa.lidar/files/hitbox_test.xml", x, y )
end

function OnWorldPreUpdate() 
	dofile("mods/evaisa.lidar/files/raytracing.lua")
end


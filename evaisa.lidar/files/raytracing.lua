Vector = dofile_once("mods/evaisa.lidar/files/vector.lua")
Array = dofile_once("mods/evaisa.lidar/files/store.lua")
dofile_once("data/scripts/lib/utilities.lua")

local id = 21412
local function new_id()
	id = id + 1
	return id
end

local function DrawLine(vector1, vector2, r, g, b, a)

	a = a or 1

	-- get direction, distance, and center point between points
	local dx = vector2.x - vector1.x
	local dy = vector2.y - vector1.y
	local dist = math.sqrt(dx * dx + dy * dy)

	-- normalize direction
	dx = dx / dist
	dy = dy / dist

	-- figure out rotation angle in direction, in radians
	local angle = math.atan2(dy, dx)

	GuiColorSetForNextWidget(gui, r, g, b, 1)
	GuiImage(gui, new_id(), vector1.x, vector1.y, "mods/evaisa.lidar/files/pixel.png", a, dist, 1, angle)
end

local function ui_pos(x, y)

	local virt_x = MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")
	local virt_y = MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")
	local screen_width, screen_height = GuiGetScreenDimensions(gui)
	local scale_x = virt_x / screen_width
	local scale_y = virt_y / screen_height
	local cx, cy = GameGetCameraPos()
	local sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2 - 5
	return sx, sy
end

local function vector_ui_pos(vec)
	return Vector.new(ui_pos(vec.x, vec.y))
end

local players = get_players() or {}

gui = gui or GuiCreate()

GuiStartFrame(gui)
GuiOptionsAdd(gui, GUI_OPTION.NonInteractive)


LIDAR_POINTS = LIDAR_POINTS or Array.new(256)
POINT_SET = POINT_SET or {}
local MAX_LIDAR_POINTS = 5000

local virt_x = MagicNumbersGetValue("VIRTUAL_RESOLUTION_X")
local virt_y = MagicNumbersGetValue("VIRTUAL_RESOLUTION_Y")
local screen_width, screen_height = GuiGetScreenDimensions(gui)
local scale_x = virt_x / screen_width
local scale_y = virt_y / screen_height
local cx, cy = GameGetCameraPos()


if(players[1])then
	local player = players[1]

	local px, py = EntityGetTransform(player)

	local shoot_pos = EntityGetFirstComponentIncludingDisabled(player, "HotspotComponent", "shoot_pos")

	local offset_x, offset_y = ComponentGetValue2(shoot_pos, "offset")

	px = px + offset_x
	py = py + offset_y

	-- get controls component

	local render_distance = 256

	
	local controls = EntityGetFirstComponentIncludingDisabled(player, "ControlsComponent")

	local aim_x, aim_y = ComponentGetValue2(controls, "mAimingVectorNormalized")
	local fire_2_down = ComponentGetValue2(controls, "mButtonDownFire2")
	local fire_2_frame = ComponentGetValue2(controls, "mButtonFrameFire2")

	-- rotate aim vector by random 45 degree angle
	local angle = (Random(0, 40) - 20) * math.pi / 180
	local aim_x = aim_x * math.cos(angle) - aim_y * math.sin(angle)
	local aim_y = aim_x * math.sin(angle) + aim_y * math.cos(angle)

	local new_points = {}

	local entity_list = {}

	for i, v in ipairs(EntityGetWithTag("mortal") or {})do
		if(v ~= player)then
			local hitboxes = EntityGetComponentIncludingDisabled(v, "HitboxComponent") or {}
			if(#hitboxes > 0)then
				local x, y = EntityGetTransform(v)

				--[[
					float                   aabb_min_x                                                      -5 [-15, 15]                    ""
					float                   aabb_max_x                                                      5 [-15, 15]                     ""
					float                   aabb_min_y                                                      -5 [-15, 15]                    ""
					float                   aabb_max_y                                                      5 [-15, 15]                     ""				
				]]
				local entity_bounds_radius = 0
				local aabb_min_x = nil
				local aabb_max_x = nil
				local aabb_min_y = nil
				local aabb_max_y = nil
				for _, hitbox in ipairs(hitboxes)do
					aabb_min_x = ComponentGetValue2(hitbox, "aabb_min_x")
					aabb_max_x = ComponentGetValue2(hitbox, "aabb_max_x")
					aabb_min_y = ComponentGetValue2(hitbox, "aabb_min_y")
					aabb_max_y = ComponentGetValue2(hitbox, "aabb_max_y")

					local top_left_x = x + aabb_min_x
					local top_left_y = y + aabb_min_y
					local top_right_x = x + aabb_max_x
					local top_right_y = y + aabb_min_y
					local bottom_left_x = x + aabb_min_x
					local bottom_left_y = y + aabb_max_y
					local bottom_right_x = x + aabb_max_x
					local bottom_right_y = y + aabb_max_y

					local bounds_radius = math.max(
						(top_left_x - x) * (top_left_x - x) + (top_left_y - y) * (top_left_y - y),
						(top_right_x - x) * (top_right_x - x) + (top_right_y - y) * (top_right_y - y),
						(bottom_left_x - x) * (bottom_left_x - x) + (bottom_left_y - y) * (bottom_left_y - y),
						(bottom_right_x - x) * (bottom_right_x - x) + (bottom_right_y - y) * (bottom_right_y - y)
					)
					entity_bounds_radius = math.max(entity_bounds_radius, bounds_radius)
				end

				if(entity_bounds_radius > 0)then
					table.insert(entity_list, {
						id = v,
						x = x,
						y = y,
						radius = entity_bounds_radius,
						aabb_min_x = aabb_min_x,
						aabb_max_x = aabb_max_x,
						aabb_min_y = aabb_min_y,
						aabb_max_y = aabb_max_y
					})
				end
			end
		end
	end

	local raycast = function(x, y, far_x, far_y, no_convert)
		local was_entity = false

		local dx = far_x - x
		local dy = far_y - y

		local distance = math.sqrt(dx * dx + dy * dy)

		local step_x = dx / distance
		local step_y = dy / distance

		local steps = math.floor(distance)

		local entity_x = nil
		local entity_y = nil
		local entity_radius = nil

		for i = 0, steps, 1 do
			local step_x = math.floor(x + step_x * i) + 0.5
			local step_y = math.floor(y + step_y * i) + 0.5

			for _, entity in ipairs(entity_list)do
				
				

				local dx = step_x - entity.x
				local dy = step_y - entity.y
	
				local distance = math.sqrt(dx * dx + dy * dy)

				if(distance < entity.radius)then
					--print("hit_entity")
					-- check if point is within aabb 
					local aabb_min_x = entity.aabb_min_x + entity.x
					local aabb_max_x = entity.aabb_max_x + entity.x
					local aabb_min_y = entity.aabb_min_y + entity.y
					local aabb_max_y = entity.aabb_max_y + entity.y

					if(step_x >= aabb_min_x and step_x <= aabb_max_x and step_y >= aabb_min_y and step_y <= aabb_max_y)then
						was_entity = true
						entity_x = entity.x
						entity_y = entity.y
						entity_radius = entity.radius
						local physics_comp = EntityGetFirstComponentIncludingDisabled(entity.id, "PhysicsBodyComponent")
						local physics2_comp = EntityGetFirstComponentIncludingDisabled(entity.id, "PhysicsBody2Component")
	
						if(physics_comp or physics2_comp)then
							no_convert = true
						end

						if(not no_convert)then
							EntityConvertToMaterial( entity.id, "mortal_lidar" )
						end
						goto end_loop
					end

					

				end
			end
		end

		::end_loop::
		

		local hit, hit_x, hit_y = RaytraceSurfaces( x, y, far_x, far_y )

		if(was_entity and not no_convert)then
			local material_converter_entity = EntityCreateNew()
			EntityAddComponent2(material_converter_entity, "MagicConvertMaterialComponent", {
				radius = entity_radius,
				from_material = CellFactory_GetType("mortal_lidar"),
				to_material = CellFactory_GetType("air"),
				kill_when_finished = true,
				steps_per_frame = 512,
			})
			EntitySetTransform(material_converter_entity, entity_x, entity_y)
			--ConvertMaterialOnAreaInstantly( entity_x - entity_radius, entity_y - entity_radius, entity_radius * 2, entity_radius * 2, CellFactory_GetType("mortal_lidar"), CellFactory_GetType("air"), false, false )
		end
		return hit, hit_x, hit_y, was_entity
	end

	local function cast_ray(x, y, dir_x, dir_y, distance, iterations, current_iterations)
		profile_ray = profile_ray or profiler.new("lidar_ray")
		profile_ray:start()
		current_iterations = current_iterations or 0
	
		local far_x, far_y = x + (dir_x * distance), y + (dir_y * distance)
	
		local hit, hit_x, hit_y, was_entity = raycast( x, y, far_x, far_y )
	
		
		

		local ui_pos = vector_ui_pos(Vector.new(hit_x, hit_y))
			

		DrawLine(vector_ui_pos(Vector.new(x, y)), vector_ui_pos(Vector.new(hit_x, hit_y)), 1, 0, 0, 0.3)
			
		if(hit)then
			-- move one further
			hit_x = hit_x + (aim_x)
			hit_y = hit_y + (aim_y)

			-- round to nearest integer
			hit_x = math.floor(hit_x)
			hit_y = math.floor(hit_y)


			if(not (LIDAR_POINTS:get(hit_x, hit_y)))then
				table.insert(POINT_SET, {x = hit_x, y = hit_y})
				
				table.insert(new_points, {x = hit_x, y = hit_y})
				LIDAR_POINTS:set(hit_x, hit_y, was_entity and 1 or 0)
			end

			

			if(current_iterations < iterations)then
				local found_normal, normal_x, normal_y, distance_from_surface = GetSurfaceNormal( hit_x, hit_y, 6, 32 )
				if(found_normal)then
					-- bounce ray
					local new_dir_x = dir_x - 2 * (normal_x * dir_x + normal_y * dir_y)
					local new_dir_y = dir_y - 2 * (normal_x * dir_y - normal_y * dir_x)
					-- cast ray again
					--cast_ray(hit_x, hit_y, new_dir_x, new_dir_y, distance_from_surface, iterations, current_iterations + 1)
				end
			end
		end
		profile_ray:stop()
		--profile_ray:print()
	end

	--GamePrint(tostring(#POINT_SET) .. " points saved")
	if(#POINT_SET > MAX_LIDAR_POINTS)then
		local item = table.remove(POINT_SET, 1)
		LIDAR_POINTS:delete(item.x, item.y)
	end

	not_first_scan = not_first_scan or false 
	was_scanning = was_scanning or false
	local px = math.floor(px)
	local py = math.floor(py)
	local world_state = GameGetWorldStateEntity()
	if(fire_2_down)then
		was_scanning = true
		if(fire_2_frame == GameGetFrameNum() and not not_first_scan)then
			GamePlaySound("mods/evaisa.lidar/lidar.bank", "lidar/scan_start", 0, 0)
			print("scan start")
			not_first_scan = true
		elseif(GameGetFrameNum() - fire_2_frame > 20)then
			if(world_state ~= nil)then
				local audio_loop_component = EntityGetFirstComponentIncludingDisabled(world_state, "AudioLoopComponent", "lidar_audio_loop")
				if(audio_loop_component == nil)then
					local comp = EntityAddComponent2(world_state, "AudioLoopComponent", {
						file="mods/evaisa.lidar/lidar.bank",
						event_name="lidar/scan_loop",
						auto_play=true,
					})
					ComponentAddTag(comp, "lidar_audio_loop")
				end
			end
			cast_ray(px, py, aim_x, aim_y, render_distance, 0)
		end
	else
		if(was_scanning)then
			GamePlaySound("mods/evaisa.lidar/lidar.bank", "lidar/scan_stop", 0, 0)
			was_scanning = false
		end
		if(world_state ~= nil)then
			local audio_loop_component = EntityGetFirstComponentIncludingDisabled(world_state, "AudioLoopComponent", "lidar_audio_loop")
			if(audio_loop_component ~= nil)then
				EntityRemoveComponent(world_state, audio_loop_component)
			end
		end
		
	end
	--[[profile_test = profile_test or profiler.new("lidar_test")
	profile_test:clear()
	profile_draw = profile_draw or profiler.new("lidar_draw")
	profile_draw:start()
	local first_iteration = true]]

	local function draw_point(x, y, enemy)
		if(enemy)then
			GameCreateSpriteForXFrames("mods/evaisa.lidar/files/pixel_red.png", x + 0.5, y + 0.5, true, 0, 0, 2, true)
		else
			GameCreateSpriteForXFrames("mods/evaisa.lidar/files/pixel_orange.png", x + 0.5, y + 0.5, true, 0, 0, 2, true)
		end

	end


	if(GameGetFrameNum() % 30 == 0)then
		for x = px - render_distance, px + render_distance do
			for y = py - render_distance, py + render_distance do

				local value = LIDAR_POINTS:get(x, y)

				
				if(value ~= nil)then
					--ConvertMaterialOnAreaInstantly( x, y, 128, 128, CellFactory_GetType("mortal_lidar"), CellFactory_GetType("air"), false, false )

					local check_hit, check_x, check_y = raycast( x, y, x + 0.4, y + 0.4, true )
	
					if(check_hit)then

						--[[local sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2 - 5
						GuiColorSetForNextWidget(gui, 1, 0, 0, 0.7)
						GuiText(gui, sx, sy, ".")]]
						draw_point(x, y, value == 1)
					else
						LIDAR_POINTS:delete(x, y)
					end
				end
				
			end
		end
	else
		for x = px - render_distance, px + render_distance do
			for y = py - render_distance, py + render_distance do
				local value = LIDAR_POINTS:get(x, y)

				--ConvertMaterialOnAreaInstantly( x, y, 1000, 1000, CellFactory_GetType("mortal_lidar"), CellFactory_GetType("air"), false, false )

				if(value ~= nil)then
					local was_new = false
					for k, v in ipairs(new_points)do
						if(v.x == x and v.y == y)then
							was_new = true
							break
						end
					end

					

					if(was_new and not value == 1)then
						local check_hit, check_x, check_y = raycast( x, y, x + 0.4, y + 0.4, true )
	
						if(check_hit)then
							--[[
							local sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2 - 5
							GuiColorSetForNextWidget(gui, 1, 0, 0, 0.7)
							GuiText(gui, sx, sy, ".")]]
							draw_point(x, y, value == 1)
							
						else
							LIDAR_POINTS:delete(x, y)
						end
					else
						--[[
						local sx, sy = (x - cx) / scale_x + screen_width / 2 + 1.5, (y - cy) / scale_y + screen_height / 2 - 5
						GuiColorSetForNextWidget(gui, 1, 0, 0, 0.7)
						GuiText(gui, sx, sy, ".")]]
	
						draw_point(x, y, value == 1)
					end

				end
				
			end
		end
	end

	--profile_draw:stop()
	--profile_test:print_sum()
	--profile_draw:print()

end
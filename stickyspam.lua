StickySpammer = nil
if not StickySpammer then
	StickySpammer = {
		configFolder = engine.GetGameDir() or os.getenv("localAPPDATA"),
		Key = KEY_F,
		Rage = true,
		DoAutoDetonate = true,
		ExplosionDistance = 160,
		Charge = 0.0,
		Menu = nil,
	}
end

local lastLaunch = nil
local err, Menu = pcall(require, "Menu")
assert(err, "MenuLib 404")
assert(Menu.Version >= 1.5, "Get a newer version of menulib.")


StickySpammer.Menu = Menu.Create("stickyspammer", MenuFlags.AutoSize)
StickySpammer.ExplosionDistance = StickySpammer.Menu:AddComponent(Menu.Slider("Explosion distance", 10, 250, StickySpammer.ExplosionDistance))
StickySpammer.Charge = StickySpammer.Menu:AddComponent(Menu.Slider("Charge stickies (ms)", 0, 10000, StickySpammer.Charge, ItemFlags.FullWidth))

StickySpammer.DoAutoDetonate = StickySpammer.Menu:AddComponent(Menu.Checkbox("Auto detonate", StickySpammer.DoAutoDetonate, ItemFlags.FullWidth))
StickySpammer.Rage = StickySpammer.Menu:AddComponent(Menu.Checkbox("Rage (no visibility check)", StickySpammer.Rage, ItemFlags.FullWidth))
StickySpammer.Key = StickySpammer.Menu:AddComponent(Menu.Keybind("keybind", StickySpammer.Key))
StickySpammer.Menu:AddComponent(Menu.Button("save config", function() 
	StickySpammer.save()
end))




function StickySpammer.save()
	local data = StickySpammer.serialize(StickySpammer)

	local file = string.format("%s\\..\\StickySpammer.cfg", engine.GetGameDir())
	local handle = io.open(file, "w")
	if handle then
		handle:write(data)
		handle:close()
		print(string.format("config saved to %s", file))
	else
		print(string.format("failed to write file? %s", file))
	end
	

end

function StickySpammer.load()
	local file = string.format("%s\\..\\StickySpammer.cfg", engine.GetGameDir())
	
	local handle = io.open(file, "rb")
	if handle then
		local input = handle:read("*a")
		for k, v in pairs(StickySpammer.deSerialize(input)) do
			StickySpammer[k].Value = v
		end
		handle:close()

		print("config loaded")
	else
		print(string.format("failed to load config, does it exist? (%s)", file))
	end

end



function StickySpammer.deSerialize(input)
	local t = {}
	for k, v in string.gmatch(input, "([^&=]+)=([^&=]+)") do
		if v == "true" then
			t[k] = true
		elseif v == "false" then
			t[k] = false
		elseif string.match(v, "^%d+%.%d+$") then
			t[k] = tonumber(v)
		else
			t[k] = tonumber(v) or v
		end
	end
	return t	
end


-- only serialize bool & int
function StickySpammer.serialize(input)
	local result = {}
	for k, v in pairs(input) do
		local valueStr
		local _t = type(v)
		if _t == "boolean" or _t == "number" or _t == "table" then
			if v.Value or v.GetValue then
				v = v:GetValue()
				if type(v) == "boolean" then
					valueStr = v and "true" or "false"
				else
					valueStr = tostring(v)
				end
				table.insert(result, string.format("%s=%s", k, valueStr))
			end
		end
	end
	return table.concat(result, "&")
end

-- copied LnxLib
function StickySpammer.visible(target, player, nonplayer)
	local from = player:GetAbsOrigin()
	local to = target:GetAbsOrigin()
	--const 
	CONTENTS_SOLID = 0x1
	CONTENTS_WINDOW = 0x2
	CONTENTS_MONSTER = 0x2000000
	
	CONTENTS_MOVEABLE = 0x4000 
	CONTENTS_DEBRIS = 0x4000000
	CONTENTS_HITBOX = 0x40000000
	

	CONTENTS_GRATE = 0x8 -- I have no idea wtf this is
	MASK_SHOT = (CONTENTS_SOLID|CONTENTS_MOVEABLE|CONTENTS_MONSTER|CONTENTS_WINDOW|CONTENTS_DEBRIS|CONTENTS_HITBOX)
	local traceFeet = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE)


	if nonplayer ~= nil then
		return ((traceFeet.entity == target) or (traceFeet.fraction > 0.99))
	end

	local vo = player:GetPropVector("localdata", "m_vecViewOffset[0]")
	local adj = player:GetAbsOrigin() + vo
	local vh = Vector3(0, 0, (adj - player:GetAbsOrigin()):Length())
	local traceHead = engine.TraceLine(from + vh, to, MASK_SHOT | CONTENTS_GRATE)
	local traceHead2 = engine.TraceLine(from, to + vh, MASK_SHOT | CONTENTS_GRATE)
	return ((traceFeet.entity == target) or (traceFeet.fraction > 0.99)) or
		((traceHead.entity == target) or (traceHead.fraction > 0.99)) or
		((traceHead2.entity == target) or (traceHead2.fraction > 0.99))
end

function StickySpammer.stickies(entity)
	local result = {}
	local bombs = entities.FindByClass("CTFGrenadePipebombProjectile")
	for _, bomb in pairs(bombs) do
		if not bomb:IsDormant() then
			local owner = bomb:GetPropEntity("m_hLauncher")
			if owner ~= nil and owner:GetPropEntity("m_hOwnerEntity") == entity then
				table.insert(result, bomb)
			end
		end
	end

	return result
end




function StickySpammer.autoDetonate(cmd)
	local me = entities.GetLocalPlayer()
	if not me or not me:IsAlive() then return end
	local class = me:GetPropInt("m_iClass")
	if not class or class ~= 4 then return end
	if not StickySpammer.DoAutoDetonate.Value then return end


	local myBombs = StickySpammer.stickies(me)
	local players = entities.FindByClass("CTFPlayer")


	if gui.GetValue("aim sentry") == 1 then
		for k, v in pairs(entities.FindByClass("CObjectSentrygun")) do
			table.insert(players, v)
			print("adding: "..tostring(v))
		end
	end


	if gui.GetValue("aim other buildings") == 1 then
		for k, v in pairs(entities.FindByClass("CObjectTeleporter")) do
			table.insert(players, v)
		end

		for k, v in pairs(entities.FindByClass("CObjectDispenser")) do
			table.insert(players, v)
		end
	end

	if #myBombs < 1 or #players < 1 then return end

	for _, player in pairs(players) do
		if player and (player:GetClass() ~= "CTFPlayer" or player:IsAlive()) then
			if player:GetTeamNumber() ~= me:GetTeamNumber() then -- verify that it's the enemy and alive..
				if StickySpammer.Rage.Value or (StickySpammer.visible(player, me)) then -- rage / visibility check
					if gui.GetValue("ignore cloaked") == 1 and not player:InCond(4) then -- spy cloak check
						for _, bomb in pairs(myBombs) do
							if (bomb:GetAbsOrigin() - player:GetAbsOrigin()):Length() < StickySpammer.ExplosionDistance.Value then -- check distance
								if StickySpammer.visible(player, bomb, true) then -- ensure that sticky can actually affect the target..
									cmd:SetButtons(cmd:GetButtons() | IN_ATTACK2) --detonatey
								end
							end
						end
					end
				end
			end
		end
	end


end


function StickySpammer.spam(cmd)
	local me = entities:GetLocalPlayer()
	if not me or not me:IsAlive() then return end
	local class = me:GetPropInt("m_iClass")
	if not class or class ~= 4 then return end	
	local weapon = me:GetPropEntity("m_hActiveWeapon")

	--[[
	if weapon and weapon:GetPropFloat("m_flChargeBeginTime") > 0 then
		print(tostring(weapon:GetPropFloat("m_flChargeBeginTime")), tostring(globals.CurTime()))
		print(string.format("things: %s", tostring((globals.CurTime() - weapon:GetPropFloat("m_flChargeBeginTime")) * 1000 )))

	end
	--]]
	if StickySpammer.Key and StickySpammer.Key:GetValue() ~= KEY_NONE and
		weapon and weapon:GetWeaponID() == TF_WEAPON_PIPEBOMBLAUNCHER and 
		input.IsButtonDown(StickySpammer.Key:GetValue()) then
		local prop = weapon:GetPropFloat("m_flChargeBeginTime")
		if lastLaunch ~= prop and ((globals.CurTime() - prop) * 1000) > (StickySpammer.Charge.Value) then
			cmd:SetButtons(cmd:GetButtons() & ~IN_ATTACK)
			lastLaunch = prop
		else
			cmd:SetButtons(cmd:GetButtons() | IN_ATTACK)
		end

	end
end


local function unloadStickySpam()
	UnloadLib()
	Menu.RemoveMenu(StickySpammer.Menu)
	StickySpammer.Menu = nil
	StickySpammer = nil
end


StickySpammer.load()
callbacks.Register("CreateMove", StickySpammer.autoDetonate)
callbacks.Register("CreateMove", StickySpammer.spam)
callbacks.Register("Unload", unloadStickySpam)

if not StickySpammer then
	StickySpammer = {
		Key = KEY_F,
		Rage = true,
		DoAutoDetonate = true,
		ExplosionDistance = 160,
		Menu = nil
	}
end


local err, Menu = pcall(require, "Menu")
assert(err, "MenuLib 404")
assert(Menu.Version >= 1.5, "Get a newer version of menulib.")


StickySpammer.Menu = Menu.Create("stickyspammer", MenuFlags.AutoSize)
StickySpammer.ExplosionDistance = StickySpammer.Menu:AddComponent(Menu.Slider("Explosion distance", 10, 250, StickySpammer.ExplosionDistance))

StickySpammer.DoAutoDetonate = StickySpammer.Menu:AddComponent(Menu.Checkbox("Auto detonate", StickySpammer.DoAutoDetonate, ItemFlags.FullWidth))
StickySpammer.Rage = StickySpammer.Menu:AddComponent(Menu.Checkbox("Rage (no visibility check)", StickySpammer.Rage, ItemFlags.FullWidth))
StickySpammer.Key = StickySpammer.Menu:AddComponent(Menu.Keybind("keybind", StickySpammer.Key))
StickySpammer.Menu:AddComponent(Menu.Button("save config", function() 
	print("this doesn't exist, we cant write to disk apparently.")
end))





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
	--print("Doautodetonate: "..tostring(StickySpammer.DoAutoDetonate))
	if not StickySpammer.DoAutoDetonate.Value then return end


	local myBombs = StickySpammer.stickies(me)

	local players = entities.FindByClass("CTFPlayer")

	if #myBombs > 0 then
		for _, player in pairs(players) do
			if player and player:IsAlive() and player:GetTeamNumber() ~= me:GetTeamNumber() then
				if StickySpammer.Rage.Value or (StickySpammer.visible(player, me)) then
					if gui.GetValue("ignore cloaked") == 1 and not player:InCond(4) then
						for _, bomb in pairs(myBombs) do
							if (bomb:GetAbsOrigin() - player:GetAbsOrigin()):Length() < StickySpammer.ExplosionDistance.Value then 
								if StickySpammer.visible(player, bomb, true) then
									cmd:SetButtons(cmd:GetButtons() | IN_ATTACK2) --detonateyy
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
		
	print(tostring(MOUSE_4))
	local weapon = me:GetPropEntity("m_hActiveWeapon")
	if StickySpammer.Key:GetValue() ~= KEY_NONE and weapon and weapon:GetWeaponID() == TF_WEAPON_PIPEBOMBLAUNCHER and input.IsButtonDown(StickySpammer.Key:GetValue()) then
		print(weapon:GetPropFloat("m_flChargeBeginTime"))
		if weapon:GetPropFloat("m_flChargeBeginTime") > 0 then
			cmd:SetButtons(cmd:GetButtons() & ~IN_ATTACK) --detonateyy
		else
			cmd:SetButtons(cmd:GetButtons() | IN_ATTACK) --detonateyy
		end
	end
end


local function unloadStickySpam()
	UnloadLib()
	Menu.RemoveMenu(StickySpammer.Menu)
	StickySpammer.Menu = nil
	StickySpammer = nil
end


callbacks.Register("CreateMove", StickySpammer.autoDetonate)
callbacks.Register("CreateMove", StickySpammer.spam)
callbacks.Register("Unload", unloadStickySpam)
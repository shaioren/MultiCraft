addonName, mc_addon, totalToCreate, sliderValue = 'MultiCraft', {}, 1, 1

local NO_SKILL = 0
local BLACKSMITHING_SKILL = 1
local CLOTHING_SKILL = 2
local ENCHANTING_SKILL = 3
local ALCHEMY_SKILL = 4
local PROVISIONING_SKILL = 5
local WOODWORKING_SKILL = 6

local CREATION_MODE = 2
local DECONSTRUCTION_MODE = 4

local current_craft = NO_SKILL

function MultiCraft_Initialize(self)
	self:RegisterForEvent(EVENT_CRAFTING_STATION_INTERACT, MultiCraft_ReplacePanelFunctions)
	self:RegisterForEvent(EVENT_CRAFT_STARTED, MultiCraft_HideUI)
	self:RegisterForEvent(EVENT_END_CRAFTING_STATION_INTERACT, MultiCraft_Cleanup)
	
	-- Set up function overrides
	-- Provisioner
	PROVISIONER.mode = CREATION_MODE
	PROVISIONER.recipeTree.RealSelectNode = PROVISIONER.recipeTree.SelectNode
	PROVISIONER.recipeTree.SelectNode = function(...)
		PROVISIONER.recipeTree.RealSelectNode(...)
		
		MultiCraft_ResetSlider()
	end
	
	-- create function
	PROVISIONER.RealCreate = PROVISIONER.Create
	PROVISIONER.Create = function(...)
		MultiCraft_Create()
	end
	
	-- Alchemy
	-- Enchanting
	-- Smithing
	-- tab change
	SMITHING.RealSetMode = SMITHING.SetMode
	SMITHING.SetMode = function(...)
		SMITHING.RealSetMode(...)
		MultiCraft_ResetSlider()
	end
	
	-- pattern selection in creation
	SMITHING.creationPanel.RealOnSelectedPatternChanged = SMITHING.creationPanel.OnSelectedPatternChanged
	SMITHING.creationPanel.OnSelectedPatternChanged = function(...)
		SMITHING.creationPanel.RealOnSelectedPatternChanged(...)
		MultiCraft_ResetSlider()
	end
	
	-- item selection in deconstruction
	SMITHING.deconstructionPanel.RealOnSlotChanged = SMITHING.deconstructionPanel.OnSlotChanged
	SMITHING.deconstructionPanel.OnSlotChanged = function(...)
		SMITHING.deconstructionPanel.RealOnSlotChanged(...)
		MultiCraft_ResetSlider()
	end
	
	-- create function
	SMITHING.creationPanel.RealCreate = SMITHING.creationPanel.Create
	SMITHING.creationPanel.Create = function(...)
		MultiCraft_Create()
	end
	
	-- extract function
	SMITHING.deconstructionPanel.RealExtract = SMITHING.deconstructionPanel.Extract
	SMITHING.deconstructionPanel.Extract = function(...)
		MultiCraft_Extract()
	end
end

function MultiCraft_ReplacePanelFunctions(unknown, craftSkill)
	current_craft = craftSkill
	mc_addon.object = nil
	
	if craftSkill == PROVISIONING_SKILL then
		-- grab the provisioner instance
		if not mc_addon.object then mc_addon.object = PROVISIONER end
		EmitMessage("MC_Addon.Object = PROVISIONER")
		MultiCraft:SetHidden(false)		
	elseif craftSkill == ENCHANTING_SKILL then
	elseif craftSkill == ALCHEMY_SKILL then
	else
		-- grab the smithing instance
		if not mc_addon.object then mc_addon.object = SMITHING end
		EmitMessage("MC_Addon.Object = SMITHING")
	end
	
	MultiCraft_ResetSlider()
end

function MultiCraft_HideUI(...)
	MultiCraft:SetHidden(true)
end

function MultiCraft_Cleanup(...)
	MultiCraft_HideUI(...)
	mc_addon.object = nil
	current_craft = NO_SKILL
	EmitMessage("MC_Addon.Object = nil")
	
end

function MultiCraft_EnableOrDisableUI()
	if not mc_addon.object then return end
	hidden = true
	
	if current_craft == PROVISIONING_SKILL then
		if mc_addon.object:IsCraftable() then
			hidden = false
		end
	elseif current_craft == ALCHEMY_SKILL then
		hidden = true
	elseif current_craft == ENCHANTING_SKILL then
		hidden = true
	else
		if (mc_addon.object.mode == CREATION_MODE and mc_addon.object.creationPanel:IsCraftable()) or
		   (mc_addon.object.mode == DECONSTRUCTION_MODE and mc_addon.object.deconstructionPanel:IsExtractable()) then
			hidden = false
		end
	end
	EmitMessage("hidden = " .. tostring(hidden))
	MultiCraft:SetHidden(hidden)
end

function MultiCraft_ResetSlider()
	if not mc_addon.object then return end
	MultiCraft_EnableOrDisableUI()
	
	local numCraftable = 1
	
	EmitMessage("current craft is " .. current_craft)
	if current_craft == PROVISIONING_SKILL then
		data = mc_addon.object.recipeTree:GetSelectedData()
		if data ~= nil then
			numCraftable = data.numCreatable
		end		
	elseif current_craft == ALCHEMY_SKILL then
		numCraftable = 1
	elseif current_craft == ENCHANTING_SKILL then
		numCraftable = 1
	elseif current_craft ~= NO_SKILL then
		if mc_addon.object.mode == CREATION_MODE then
			if mc_addon.object.creationPanel:IsCraftable() then
				EmitMessage("SMITHING Creation")
				-- determine metrics for the slider
				patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex = mc_addon.object.creationPanel:GetAllCraftingParameters()
				materialCount = GetCurrentSmithingMaterialItemCount(patternIndex, materialIndex) / materialQuantity
				styleItemCount = GetCurrentSmithingStyleItemCount(styleIndex)
				traitCount = GetCurrentSmithingTraitItemCount(traitIndex)
				
				numCraftable = zo_min(materialCount, styleItemCount)
				
				if traitIndex ~= 1 then
					numCraftable = zo_min(numCraftable, traitCount)
				end
			end
		elseif mc_addon.object.mode == DECONSTRUCTION_MODE then
			if mc_addon.object.deconstructionPanel:IsExtractable() then
				numCraftable = mc_addon.object.deconstructionPanel.extractionSlot.craftingInventory.itemCounts[mc_addon.object.deconstructionPanel.extractionSlot.itemInstanceId]
			end
		end
	end
	
	EmitMessage("numCraftable = " .. tostring(zo_floor(numCraftable)))
	MultiCraftSlider:SetValue(1)	
	if numCraftable == 1 then
		MultiCraftSlider:SetHidden(true)
		MultiCraft_SetSliderLabelValue()
	else
		MultiCraftSlider:SetHidden(false)
		MultiCraftSlider:SetMinMax(1, zo_floor(numCraftable))
	end
end

function MultiCraft_SetSliderLabelValue()
	if not mc_addon.object then return end
	value = MultiCraftSlider:GetValue()	
	sliderValue = value;
	
	if mc_addon.object.mode == CREATION_MODE then
		MultiCraftDeconstructionLabel:SetHidden(true)
		MultiCraftCreationLabel:SetHidden(false)
		MultiCraftCreationLabel:SetText(string.format("%d", value))
	elseif mc_addon.object.mode == DECONSTRUCTION_MODE then
		MultiCraftCreationLabel:SetHidden(true)
		MultiCraftDeconstructionLabel:SetHidden(false)
		MultiCraftDeconstructionLabel:SetText(string.format("%d", value))
	end
end

function MultiCraft_Create()
	if mc_addon.object.mode ~= CREATION_MODE then return end
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_CRAFT_COMPLETED, MultiCraft_ContinueCraft)
	
	totalToCreate = zo_floor(sliderValue)
	
	if current_craft == PROVISIONING_SKILL then
		if not mc_addon.object:IsCraftable() then return end
		mc_addon.object:RealCreate()
	else
		if not mc_addon.object.creationPanel:IsCraftable() then return end
		mc_addon.object.creationPanel:RealCreate()
	end
end

function MultiCraft_ContinueCraft(...)
	totalToCreate = totalToCreate - 1
		
	if totalToCreate ~= 0 then
		if current_craft == PROVISIONING_SKILL then
			mc_addon.object:RealCreate()
		else
			mc_addon.object.creationPanel:RealCreate()
		end
	else
		EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_CRAFT_COMPLETED)
	end
end

function MultiCraft_Extract()
	if mc_addon.object.mode ~= DECONSTRUCTION_MODE and mc_addon.object.deconstructionPanel:IsExtractable() == false then return end
	EVENT_MANAGER:RegisterForEvent(addonName, EVENT_CRAFT_COMPLETED, MultiCraft_ContinueExtract)
	
	totalToCreate = zo_floor(sliderValue)
	mc_addon.object.deconstructionPanel:RealExtract()
end

function MultiCraft_ContinueExtract(...)
	totalToCreate = totalToCreate - 1
		
	if totalToCreate ~= 0 then
		mc_addon.object.deconstructionPanel:RealExtract()
	else
		EVENT_MANAGER:UnregisterForEvent(addonName, EVENT_CRAFT_COMPLETED)
		MultiCraft_ResetSlider()
	end
end

function EmitMessage(message)
	if (CHAT_SYSTEM) then
		if (message == nil) then
			message = "[nil]"
		elseif (message == "") then
			message = "[Empty String]"
		end
		CHAT_SYSTEM:AddMessage(message)
	end
end
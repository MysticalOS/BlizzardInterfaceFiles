WorldQuestDataProviderMixin = CreateFromMixins(MapCanvasDataProviderMixin);

function WorldQuestDataProviderMixin:SetMatchWorldMapFilters(matchWorldMapFilters)
	local wasMatchingWorldMapFilters = self:IsMatchingWorldMapFilters();
	self.matchWorldMapFilters = matchWorldMapFilters;
	if wasMatchingWorldMapFilters ~= self:IsMatchingWorldMapFilters() and self:GetMap() and self:GetMap():GetMapID() then
		self:RefreshAllData();
	end
end

function WorldQuestDataProviderMixin:IsMatchingWorldMapFilters()
	return not not self.matchWorldMapFilters;
end

function WorldQuestDataProviderMixin:SetUsesSpellEffect(usesSpellEffect)
	local usedSpellEffect = self:IsUsingSpellEffect();
	self.usesSpellEffect = usesSpellEffect;
	if usedSpellEffect ~= usesSpellEffect then
		self:EvaluateSpellEffectPin();
	end
end

function WorldQuestDataProviderMixin:IsUsingSpellEffect()
	return not not self.usesSpellEffect;
end

function WorldQuestDataProviderMixin:EvaluateSpellEffectPin()
	if not self:GetMap() then
		return;
	end

	if self:IsUsingSpellEffect() then
		if not self.spellEffectPin then
			-- a single permanent pin because we don't know the lifetime of the visual
			self.spellEffectPin = self:GetMap():AcquirePin("WorldQuestSpellEffectPinTemplate");
			self.spellEffectPin.dataProvider = self;
		end
	else
		if self.spellEffectPin then
			self:GetMap():RemoveAllPinsByTemplate("WorldQuestSpellEffectPinTemplate");
			self.spellEffectPin = nil;
		end
	end
end

function WorldQuestDataProviderMixin:HandleClick(pin)
	return self.spellEffectPin and self.spellEffectPin:TryCastSpell(pin.questID);
end

function WorldQuestDataProviderMixin:SetCheckBounties(checkBounties)
	local checkedBounties = self:IsCheckingBounties();
	self.checkBounties = checkBounties;
	if checkedBounties ~= checkBounties then
		self:EvaluateCheckBounties();
		self:SetBountyQuestID(nil);
	end
end

function WorldQuestDataProviderMixin:IsCheckingBounties()
	return not not self.checkBounties;
end

function WorldQuestDataProviderMixin:EvaluateCheckBounties()
	if not self:GetMap() then
		return;
	end

	if self:IsCheckingBounties() then
		if not self.setBountyQuestIDCallback then
			self.setBountyQuestIDCallback = function(event, ...) self:SetBountyQuestID(...); end;
		end
		self:GetMap():RegisterCallback("SetBountyQuestID", self.setBountyQuestIDCallback);
	else
		self:GetMap():UnregisterCallback("SetBountyQuestID", self.setBountyQuestIDCallback);
	end
end

function WorldQuestDataProviderMixin:SetMarkActiveQuests(markActiveQuests)
	self.markActiveQuests = markActiveQuests;
	if self:GetMap() then
		self:RefreshAllData();
	end
end

function WorldQuestDataProviderMixin:IsMarkingActiveQuests()
	return not not self.markActiveQuests;
end

function WorldQuestDataProviderMixin:OnAdded(mapCanvas)
	self.activePins = {};
	self.suppressedQuests = {};
	MapCanvasDataProviderMixin.OnAdded(self, mapCanvas);

	self:GetMap():SetPinTemplateType("WorldQuestSpellEffectPinTemplate", "CinematicModel");

	self:RegisterEvent("SUPER_TRACKED_QUEST_CHANGED");

	if not self.setFocusedQuestIDCallback then
		self.setFocusedQuestIDCallback = function(event, ...) self:SetFocusedQuestID(...); end;
	end
	if not self.clearFocusedQuestIDCallback then
		self.clearFocusedQuestIDCallback = function(event, ...) self:ClearFocusedQuestID(...); end;
	end
	if not self.setBountyQuestIDCallback then
		self.setBountyQuestIDCallback = function(event, ...) self:SetBountyQuestID(...); end;
	end
	if not self.pingQuestIDCallback then
		self.pingQuestIDCallback = function(event, ...) self:PingQuestID(...); end;
	end

	self:GetMap():RegisterCallback("SetFocusedQuestID", self.setFocusedQuestIDCallback);
	self:GetMap():RegisterCallback("ClearFocusedQuestID", self.clearFocusedQuestIDCallback);
	self:GetMap():RegisterCallback("SetBountyQuestID", self.setBountyQuestIDCallback);
	self:GetMap():RegisterCallback("PingQuestID", self.pingQuestIDCallback);

	self:EvaluateSpellEffectPin();
	self:EvaluateCheckBounties();
end

function WorldQuestDataProviderMixin:OnRemoved(mapCanvas)
	self:GetMap():UnregisterCallback("SetFocusedQuestID", self.setFocusedQuestIDCallback);
	self:GetMap():UnregisterCallback("ClearFocusedQuestID", self.clearFocusedQuestIDCallback);
	self:GetMap():UnregisterCallback("SetBountyQuestID", self.setBountyQuestIDCallback);

	MapCanvasDataProviderMixin.OnRemoved(self, mapCanvas);
end

function WorldQuestDataProviderMixin:SetFocusedQuestID(questID)
	self.focusedQuestID = questID;
	self:RefreshAllData();
end

function WorldQuestDataProviderMixin:ClearFocusedQuestID(questID)
	self.focusedQuestID = nil;
	self:RefreshAllData();
end

function WorldQuestDataProviderMixin:SetBountyQuestID(questID)
	local changed = self.bountyQuestID ~= questID;
	if changed then
		self.bountyQuestID = questID;
		if self:GetMap() then
			self:RefreshAllData();
		end
	end
end

function WorldQuestDataProviderMixin:GetBountyQuestID()
	return self.bountyQuestID;
end

function WorldQuestDataProviderMixin:PingQuestID(questID)
	if self.pingPin then
		self.pingPin:Stop();
	end

	if not self.pingPin then
		self.pingPin = self:GetMap():AcquirePin("WorldQuestPingPinTemplate");
		self.pingPin.dataProvider = self;
	end

	self.pingPin:Play(questID);
end

function WorldQuestDataProviderMixin:OnEvent(event, ...)
	if event == "SUPER_TRACKED_QUEST_CHANGED" or event == "QUEST_LOG_UPDATE" then
		self:RefreshAllData();
	end
end

function WorldQuestDataProviderMixin:RemoveAllData()
	wipe(self.activePins);
	self:GetMap():RemoveAllPinsByTemplate(self:GetPinTemplate());
end

function WorldQuestDataProviderMixin:OnShow()
	assert(self.ticker == nil);
	self.ticker = C_Timer.NewTicker(0.5, function() self:RefreshAllData() end);
	self:RegisterEvent("QUEST_LOG_UPDATE");
end

function WorldQuestDataProviderMixin:OnHide()
	self.ticker:Cancel();
	self.ticker = nil;
	self:UnregisterEvent("QUEST_LOG_UPDATE");
end

function WorldQuestDataProviderMixin:DoesWorldQuestInfoPassFilters(info)
	local ignoreTypeRequirements = not self:IsMatchingWorldMapFilters();
	return WorldMap_DoesWorldQuestInfoPassFilters(info, ignoreTypeRequirements);
end

function WorldQuestDataProviderMixin:ShouldOverrideShowQuest(mapID, questId)
	local mapInfo = C_Map.GetMapInfo(mapID);
	if questId == GetSuperTrackedQuestID() and mapInfo.mapType == Enum.UIMapType.Continent then 
		return true;
	end
	return false; 
end 

function WorldQuestDataProviderMixin:RefreshAllData(fromOnShow)
	local pinsToRemove = {};
	for questId in pairs(self.activePins) do
		pinsToRemove[questId] = true;
	end

	local taskInfo;
	local mapCanvas = self:GetMap();
	
	local mapID = mapCanvas:GetMapID();
	if (mapID) then
		taskInfo = C_TaskQuest.GetQuestsForPlayerByMapID(mapID);
		self.matchWorldMapFilters = MapUtil.MapHasEmissaries(mapID);
	end

	if taskInfo then
		for i, info in ipairs(taskInfo) do
			if self:ShouldOverrideShowQuest(mapID, info.questId) or self:ShouldShowQuest(info) and HaveQuestData(info.questId) then
				if QuestUtils_IsQuestWorldQuest(info.questId) then
					if self:DoesWorldQuestInfoPassFilters(info) then
						pinsToRemove[info.questId] = nil;
						local pin = self.activePins[info.questId];
						if pin then
							pin:RefreshVisuals();
							pin.numObjectives = info.numObjectives;	-- Fix for quests with sequenced objectives
							pin:SetPosition(info.x, info.y); -- Fix for WOW8-48605 - WQ starting location may move based on player location and viewed map

							if self.pingPin and self.pingPin:IsAttachedToQuest(info.questId) then
								self.pingPin:SetPosition(info.x, info.y);
							end
						else
							self.activePins[info.questId] = self:AddWorldQuest(info);
						end
					end
				end
			end
		end
	end

	for questId in pairs(pinsToRemove) do
		if self.pingPin and self.pingPin:IsAttachedToQuest(questId) then
			self.pingPin:Stop();
		end

		mapCanvas:RemovePin(self.activePins[questId]);
		self.activePins[questId] = nil;
	end

	mapCanvas:TriggerEvent("WorldQuestsUpdate", mapCanvas:GetNumActivePinsByTemplate(self:GetPinTemplate()));
end

function WorldQuestDataProviderMixin:ShouldShowQuest(info)
	return not self.focusedQuestID and not self:IsQuestSuppressed(info.questId);
end

function WorldQuestDataProviderMixin:GetPinTemplate()
	return "WorldQuestPinTemplate";
end

function WorldQuestDataProviderMixin:ShouldShowExpirationIcon(questID, worldQuestType)
	if QuestUtils_ShouldDisplayExpirationWarning(questID) then
		if worldQuestType == LE_QUEST_TAG_TYPE_FACTION_ASSAULT or worldQuestType == LE_QUEST_TAG_TYPE_INVASION then
			if QuestUtils_IsQuestWithinCriticalTimeThreshold(questID) then
				return true;
			end
		else
			if QuestUtils_IsQuestWithinLowTimeThreshold(questID) then
				return true;
			end
		end
	end
	return false;
end

function WorldQuestDataProviderMixin:AddWorldQuest(info)
	local pin = self:GetMap():AcquirePin(self:GetPinTemplate());
	pin.questID = info.questId;
	pin.dataProvider = self;

	pin.worldQuest = true;
	pin.numObjectives = info.numObjectives;
	pin:UseFrameLevelType("PIN_FRAME_LEVEL_WORLD_QUEST", self:GetMap():GetNumActivePinsByTemplate(self:GetPinTemplate()));

	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(info.questId);
	local tradeskillLineID = tradeskillLineIndex and select(7, GetProfessionInfo(tradeskillLineIndex));

	pin.worldQuestType = worldQuestType;

	if rarity ~= LE_WORLD_QUEST_QUALITY_COMMON then
		pin.Background:SetTexCoord(0, 1, 0, 1);
		pin.PushedBackground:SetTexCoord(0, 1, 0, 1);
		pin.Highlight:SetTexCoord(0, 1, 0, 1);

		pin.Background:SetSize(45, 45);
		pin.PushedBackground:SetSize(45, 45);
		pin.Highlight:SetSize(45, 45);
		pin.SelectedGlow:SetSize(45, 45);

		if rarity == LE_WORLD_QUEST_QUALITY_RARE then
			pin.Background:SetAtlas("worldquest-questmarker-rare");
			pin.PushedBackground:SetAtlas("worldquest-questmarker-rare-down");
			pin.Highlight:SetAtlas("worldquest-questmarker-rare");
			pin.SelectedGlow:SetAtlas("worldquest-questmarker-rare");
		elseif rarity == LE_WORLD_QUEST_QUALITY_EPIC then
			pin.Background:SetAtlas("worldquest-questmarker-epic");
			pin.PushedBackground:SetAtlas("worldquest-questmarker-epic-down");
			pin.Highlight:SetAtlas("worldquest-questmarker-epic");
			pin.SelectedGlow:SetAtlas("worldquest-questmarker-epic");
		end
	else
		pin.Background:SetSize(75, 75);
		pin.PushedBackground:SetSize(75, 75);
		pin.Highlight:SetSize(75, 75);

		-- We are setting the texture without updating the tex coords.  Refresh visuals will handle
		-- updating the tex coords based on whether this pin is selected or not.
		pin.Background:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		pin.PushedBackground:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");
		pin.Highlight:SetTexture("Interface/WorldMap/UI-QuestPoi-NumberIcons");

		pin.Highlight:SetTexCoord(0.625, 0.750, 0.875, 1);
	end
	
	pin:RefreshVisuals();

	if isElite then
		pin.Underlay:SetAtlas("worldquest-questmarker-dragon");
		pin.Underlay:Show();
	else
		pin.Underlay:Hide();
	end

	pin.TimeLowFrame:SetShown(self:ShouldShowExpirationIcon(info.questId, worldQuestType));
	
	pin:SetPosition(info.x, info.y);

	C_TaskQuest.RequestPreloadRewardData(info.questId);

	return pin;
end

function WorldQuestDataProviderMixin:SuppressQuest(questID)
	self.suppressedQuests[questID] = GetTime();
	self:RefreshAllData();
end

local WORLD_QUEST_SUPPRESSION_TIME_SECS = 60.0;

function WorldQuestDataProviderMixin:IsQuestSuppressed(questID)
	local lastSuppressedTime = self.suppressedQuests[questID];
	if lastSuppressedTime then
		if GetTime() - lastSuppressedTime < WORLD_QUEST_SUPPRESSION_TIME_SECS then
			return true;
		end
		self.suppressedQuests[questID] = nil;
	end
	return false;
end

--[[ World Quest Pin ]]--
WorldQuestPinMixin = CreateFromMixins(MapCanvasPinMixin);

function WorldQuestPinMixin:OnLoad()
	self.UpdateTooltip = self.OnMouseEnter;
end

function WorldQuestPinMixin:RefreshVisuals()
	local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = GetQuestTagInfo(self.questID);
	local selected = self.questID == GetSuperTrackedQuestID();
	self.Glow:SetShown(selected);
	self.SelectedGlow:SetShown(rarity ~= LE_WORLD_QUEST_QUALITY_COMMON and selected);
	
	if rarity == LE_WORLD_QUEST_QUALITY_COMMON then
		if selected then
			self.Background:SetTexCoord(0.500, 0.625, 0.375, 0.5);
			self.PushedBackground:SetTexCoord(0.375, 0.500, 0.375, 0.5);
		else
			self.Background:SetTexCoord(0.875, 1, 0.375, 0.5);
			self.PushedBackground:SetTexCoord(0.750, 0.875, 0.375, 0.5);
		end
	end

	local bountyQuestID = self.dataProvider:GetBountyQuestID();
	self.BountyRing:SetShown(bountyQuestID and IsQuestCriteriaForBounty(self.questID, bountyQuestID));

	local inProgress = self.dataProvider:IsMarkingActiveQuests() and C_QuestLog.IsOnQuest(self.questID);
	local atlas, width, height = QuestUtil.GetWorldQuestAtlasInfo(worldQuestType, inProgress, tradeskillLineIndex);
	self.Texture:SetAtlas(atlas);
	if self.worldQuestType == LE_QUEST_TAG_TYPE_PET_BATTLE then
		self.Texture:SetSize(26, 22);
	else
		self.Texture:SetSize(width * 2, height * 2);
	end
end

function WorldQuestPinMixin:OnMouseEnter()
	TaskPOI_OnEnter(self);
end

function WorldQuestPinMixin:OnMouseLeave()
	TaskPOI_OnLeave(self);
end

function WorldQuestPinMixin:OnClick(button)
	if not self.dataProvider:HandleClick(self) then
		if ( not ChatEdit_TryInsertQuestLinkForQuestID(self.questID) ) then
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);

			if IsShiftKeyDown() then
				if IsWorldQuestHardWatched(self.questID) or (IsWorldQuestWatched(self.questID) and GetSuperTrackedQuestID() == self.questID) then
					BonusObjectiveTracker_UntrackWorldQuest(self.questID);
				else
					BonusObjectiveTracker_TrackWorldQuest(self.questID, true);
				end
			else
				if IsWorldQuestHardWatched(self.questID) then
					SetSuperTrackedQuestID(self.questID);
				else
					BonusObjectiveTracker_TrackWorldQuest(self.questID);
				end
			end
		end
	end
end

function WorldQuestPinMixin:OnMouseDown()
	self.Background:Hide();
	self.PushedBackground:Show();
	self.Texture:SetPoint("CENTER", 2, -2);
end

function WorldQuestPinMixin:OnMouseUp()
	self.Background:Show();
	self.PushedBackground:Hide();
	self.Texture:SetPoint("CENTER", 0, 0);
end

--[[ World Quest Spell Effect Pin ]]--
WorldQuestSpellEffectPinMixin = CreateFromMixins(MapCanvasPinMixin);

function WorldQuestSpellEffectPinMixin:OnLoad()
	self:SetDisplayInfo(11686); 	-- 11686 is invisible stalker
	self:UseFrameLevelType("PIN_FRAME_LEVEL_TOPMOST");
end

function WorldQuestSpellEffectPinMixin:TryCastSpell(questID)
	if SpellCanTargetQuest() then
		if IsQuestIDValidSpellTarget(questID) then
			self:CastSpell(questID);
		else
			UIErrorsFrame:AddMessage(WORLD_QUEST_CANT_COMPLETE_BY_SPELL, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b);
		end
		return true;
	end
	return false;
end

function WorldQuestSpellEffectPinMixin:CastSpell(questID)
	UseWorldMapActionButtonSpellOnQuest(questID);
	-- Assume success for responsiveness
	local mapID = self:GetMap():GetMapID();
	local x, y = C_TaskQuest.GetQuestLocation(questID, mapID);
	if x and y then
		self.dataProvider:SuppressQuest(questID);
		local spellID, spellVisualKitID = GetWorldMapActionButtonSpellInfo();
		if spellVisualKitID then
			self:SetPosition(x, y);
			self:SetCameraTarget(0, 0, 0);
			self:SetCameraPosition(0, 0, 25);
			self:SetSpellVisualKit(spellVisualKitID);
		end
	end	
end

--[[ World Quest Ping Pin ]]--
WorldQuestPingPinMixin = CreateFromMixins(MapCanvasPinMixin);

function WorldQuestPingPinMixin:OnLoad()
	self:SetScalingLimits(1, 0.65, 0.65);
	self:UseFrameLevelType("PIN_FRAME_LEVEL_WORLD_QUEST_PING");
end

function WorldQuestPingPinMixin:Play(questID)
	local mapID = self:GetMap():GetMapID();
	local x, y = C_TaskQuest.GetQuestLocation(questID, mapID);
	if x and y then
		self:Show();
		self:SetPosition(x, y);
		self.DriverAnimation:Play();
		self.ScaleAnimation:Play();
		self.questID = questID;
	else
		self:Stop();
	end	
end

function WorldQuestPingPinMixin:Stop()
	self.DriverAnimation:Stop();
	self.ScaleAnimation:Stop();
	self:Clear();
end

function WorldQuestPingPinMixin:Clear()
	self:Hide();
	self.questID = nil;
end

function WorldQuestPingPinMixin:IsAttachedToQuest(questID)
	return self.questID == questID;
end

WorldQuestPinPingDriverAnimationMixin = {};

function WorldQuestPinPingDriverAnimationMixin:OnFinished()
	local ping = self:GetParent();
	ping.ScaleAnimation:Stop();
	ping:Clear();
end
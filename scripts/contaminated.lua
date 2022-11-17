--  	Author: Ryan Hagelstrom
--	  	Copyright © 2022
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local addEffect = nil
local parseEffects = nil
local applyDamage = nil
local messageDamage = nil
local resetHealth = nil
local resetHealthCombat2 = nil

function onInit()
	addEffect = EffectManager.addEffect
	parseEffects = PowerManager.parseEffects
	applyDamage = ActionDamage.applyDamage
	messageDamage = ActionDamage.messageDamage
	resetHealth = CharManager.resetHealth
	resetHealthCombat2 = CombatManager2.resetHealth

	EffectManager.addEffect = customAddEffect
	PowerManager.parseEffects = customParseEffect
	ActionDamage.applyDamage = customApplyDamage
	ActionDamage.messageDamage =  customMessageDamage
	CharManager.resetHealth = customResetHealth
	CombatManager2.resetHealth = customResetHealthNPC

	ActionsManager.registerResultHandler("contamination", onContamination)
	ActionsManager.registerResultHandler("recovery", onRecovery)
	if RRActionManager then
		RRActionManager.registerRollType("contamination")
	end

	table.insert(DataCommon.conditions, "contamination")
	table.sort(DataCommon.conditions)
end

function onClose()
	EffectManager.addEffect = addEffect
	PowerManager.parseEffects = parseEffects
	ActionDamage.applyDamage = applyDamage
	ActionDamage.messageDamage = messageDamage
	CharManager.resetHealth = resetHealth
	CombatManager2.resetHealth = resetHealthCombat2
end

function decrementContaminated(rActor)
	local nodeCT = ActorManager.getCTNode(rActor)
	local nLevel = 0
	for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		if nodeEffect and type(nodeEffect) == "databasenode" then
			local sEffect = DB.getValue(nodeEffect, "label", "")
			local aEffectComps = EffectManager.parseEffect(sEffect)

			for i,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
				if rEffectComp.type:lower() == "contamination" then
					if  rEffectComp.mod == 5 and  EffectManager5E.hasEffectCondition(rActor, "Incapactiated") then
						EffectManager.removeCondition(rActor, "Incapactiated")
					end

					rEffectComp.mod  = rEffectComp.mod - 1
					if  rEffectComp.mod >= 1 then
						if rEffectComp.mod > nLevel then
							nLevel = rEffectComp.mod
						end
						aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
						sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
						updateEffect(nodeCT, nodeEffect, sEffect)
					else
						EffectManager.expireEffect(nodeCT, nodeEffect, 0)
					end
				end
			end
		end
	end
	return nLevel
end

function sumContamination(rActor, nContaminationLevel)
	local nSummed = nil
	local nodeCT = ActorManager.getCTNode(rActor)
	local nodeEffectsList = DB.getChildren(nodeCT, "effects")

	for _, nodeEffect in pairs(nodeEffectsList) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)
		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type:upper() == "CONTAMINATION"  then
				rEffectComp.mod = rEffectComp.mod + nContaminationLevel
				aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
				sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
				updateEffect(nodeCT, nodeEffect, sEffect)
				nSummed = rEffectComp.mod
			end
		end
	end
	return nSummed
end

function cleanContaminationEffect(rNewEffect)
	local nContaminationLevel = 0
	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type:lower() == "contamination" or rEffectComp.original:lower() == "contamination" then
			if rEffectComp.mod == 0 then
				rEffectComp.mod = 1
				sEffectComp = sEffectComp .. ": 1"
			end
			aEffectComps[i] = sEffectComp:upper()
			nContaminationLevel = rEffectComp.mod
		end
	end

	rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return nContaminationLevel
end

function updateEffect(nodeActor, nodeEffect, sLabel)
	DB.setValue(nodeEffect, "label", "string", sLabel)
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sLabel, Interface.getString("effect_status_updated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

function getContaminationLevel(rActor)
	local nLevel = 0
	local tContaminationEffects = EffectManager5E.getEffectsByType(rActor, "CONTAMINATION")
	for _,rEffectComp in pairs(tContaminationEffects) do
		if rEffectComp.mod > nLevel then
			nLevel = rEffectComp.mod
		end
	end
	return nLevel
end

-- Parses the damage text and makes modifications to it so it prints out half damage correctly to the chat
function halfDamage(sDamage)
	local result = {}
	local regex = ("([^%s]+)"):format("[TY")
	for each in sDamage:gmatch(regex) do
	   table.insert(result, each)
	end
	local sNewDamage = ""
	for _, sClause in pairs(result) do
		if sClause:match("PE:") then
			sClause = "[TY" .. sClause
			local nClauseDamage = math.floor(tonumber(sClause:match("=%d+%)"):match("%d+"))/2)
			sClause = sClause:gsub("=%d+%)", "=" .. tostring(nClauseDamage) .. ")")
			sNewDamage = sNewDamage .. sClause
		else
			sNewDamage = sNewDamage .. sClause -- not damage clause so it passes though
		end
	end
	return sNewDamage
end

--mutation roll
function performRoll(rActor, nContamination, bGMOnly)
	local rRoll = {}
	rRoll.sType = "contamination"
	rRoll.aDice = { "d6" }
	rRoll.nMod = 0
	rRoll.nContamination = nContamination
	rRoll.sDesc = "[CONTAMINATION: " .. tostring(nContamination) .. "] "
	rRoll.bSecret = bGMOnly;

	ActionsManager.performAction(nil, rActor, rRoll)
end

-- User will have to construct the mutation table themselfs (IP reasons), roll on it themselves for mutation and apply the result.
function onContamination(rSource, rTarget, rRoll)
	if not Session.IsHost then
		return
	end
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll)
	local nTotal = ActionsManager.total(rRoll)
	if rRoll.nContamination and nTotal <= tonumber(rRoll.nContamination) then
		rMessage.text = rMessage.text .. " -> [MUTATION]"
	end
	if rRoll.nContamination and (tonumber(rRoll.nContamination) == 6) then
		rMessage.text = rMessage.text .. " [MONSTROUS TRANSFORMATION]"
	end
	Comm.deliverChatMessage(rMessage)
end

-- I think the intent of contamination: 4 is to take half and then appy whatever stuff in apply damage to that
-- so something like save for half... we do half damage, and then on save they get another half for a total of a quarter
-- This will also do 1/2 damage to all damage done by this source such as effects which could be ruled as spells
-- and will also do 1/2 damage to unarmed strikes
function customApplyDamage(rSource, rTarget, rRoll)
	local nLevel = getContaminationLevel(rSource)
	if nLevel >= 4 then
		rRoll.nTotal = math.floor(rRoll.nTotal/2)
		rRoll.sDesc = halfDamage(rRoll.sDesc)
		rRoll.sDesc = rRoll.sDesc .. " [CONTAMINATION: " .. tostring(nLevel) .. "]"
	end
	applyDamage(rSource, rTarget, rRoll)
end

-- Need to set the damage chat text here since we can't do it in applyDamage easily because that function is such a cluster
function customMessageDamage(rSource, rTarget, rRoll)
	local sContamination = rRoll.sDesc:match("%[CONTAMINATION:%s*%d*]")
	if sContamination then
		rRoll.sResults = sContamination .. " [HALF]" .. rRoll.sResults
	end
	return messageDamage(rSource, rTarget, rRoll)
end


function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end
	local nContaminated = nil
	local nContaminationLevel = cleanContaminationEffect(rNewEffect)
	if nContaminationLevel > 0  then
		local rActor = ActorManager.resolveActor(nodeCT)
		local aCancelled = EffectManager5E.checkImmunities(nil, rActor, rNewEffect)
		local bGMOnly = false
		if #aCancelled > 0 then
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"))
			EffectManager.message(sMessage, nodeCT, false, sUser)
			return
		end
		nContaminated = sumContamination(rActor, nContaminationLevel)
		if nContaminated then
			nContaminationLevel = nContaminated
		end
		--Level 5 target is Incapactiated
		if nContaminationLevel >= 5 and not EffectManager5E.hasEffectCondition(rActor, "Incapactiated") then
			EffectManager.addCondition(rActor, "Incapactiated")
		end
		if rNewEffect.nGMOnly == 1 then
			bGMOnly = true
		end
		performRoll(rActor, nContaminationLevel, bGMOnly)
	end
	if not nContaminated then
		addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end
end

function customResetHealthNPC(nodeCT, bLong)
	if bLong then
		local bRested = false
		local nodeChar = ActorManager.getCreatureNode(nodeCT)
		local rActor = ActorManager.resolveActor(nodeCT)
		local aEffectsByType = EffectManager5E.getEffectsByType(rActor, "CONTAMINATION")
		if aEffectsByType and next(aEffectsByType) then
			for _,rEffectComp in pairs(aEffectsByType) do
				if rEffectComp.mod >= 3 then
					local currentHealth = DB.getValue(nodeChar, "wounds", 0)
					resetHealthCombat2(nodeCT, bLong)
					-- reset the health back to what it was before the rest
					DB.setValue(nodeChar, "wounds", "number", currentHealth)
					bRested = true
					break
				end
			end
			decrementContaminated(rActor)
		end
		if not bRested then
			resetHealthCombat2(nodeCT, bLong)
		end
	else
		resetHealthCombat2(nodeCT, bLong)
	end
end

--Only want to disallow the HP factor of rest but the char still benfits from things like gaining back HD
function customResetHealth (nodeChar, bLong)
	local bRested = false
	if bLong then
		local rActor = ActorManager.resolveActor(nodeChar)
		local aEffectsByType = EffectManager5E.getEffectsByType(rActor, "CONTAMINATION")
		if aEffectsByType and next(aEffectsByType) then
			for _,rEffectComp in pairs(aEffectsByType) do
				if rEffectComp.mod >= 3 then
					local currentHealth = DB.getValue(nodeChar, "hp.wounds", 0)
					resetHealth(nodeChar, bLong)
					-- reset the health back to what it was before the rest
					DB.setValue(nodeChar, "hp.wounds", "number", currentHealth)
					bRested = true
					break
				end
			end
			decrementContaminated(rActor)
		end
		if not bRested then
			resetHealth(nodeChar, bLong)
		end
	else
		resetHealth(nodeChar, bLong)
	end
end

function customParseEffect(sPowerName, aWords)
	local effects = parseEffects(sPowerName,aWords)
	local i = 1;
	while aWords[i] do
		if StringManager.isWord(aWords[i],  {"gain","gains"}) then
			local bContamination = true
			local sLevel = "0"
			if StringManager.isWord(aWords[i+1],  { "1", "one", "another" }) then
				sLevel = "1"
			elseif StringManager.isWord(aWords[i+1],  { "2", "two" }) then
				sLevel = "2"
			elseif StringManager.isWord(aWords[i+1],  { "3", "three" }) then
				sLevel = "3"
			elseif StringManager.isWord(aWords[i+1],  { "4", "four" }) then
				sLevel = "4"
			elseif StringManager.isWord(aWords[i+1],  { "5", "five" }) then
				sLevel = "5"
			elseif StringManager.isWord(aWords[i+1],  { "6", "six" }) then
				sLevel = "6"
			else
				bContamination = false
			end
			if bContamination and
				StringManager.isWord(aWords[i+2], {"level", "levels"}) and
				StringManager.isWord(aWords[i+3], "of") and
				StringManager.isWord(aWords[i+4], "contamination") then
					local rContamination = {}
					rContamination.sName = "CONTAMINATION: " .. sLevel
					rContamination.startindex = i
					rContamination.endindex = i+4
					PowerManager.parseEffectsAdd(aWords, i, rContamination, effects)
			end
		end
		i = i+1
	end
	return effects
end

-- This will conflict with other extensions but I doubt many if any are playing in this space
function onRecovery(rSource, rTarget, rRoll)
	-- Get basic roll message and total
	local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
	local nTotal = ActionsManager.total(rRoll);

	-- Handle minimum damage
	if nTotal < 0 and rRoll.aDice and #rRoll.aDice > 0 then
		rMessage.text = rMessage.text .. " [MIN RECOVERY]";
		rMessage.diemodifier = rMessage.diemodifier - nTotal;
		nTotal = 0;
	end
	if ActorManager.isPC(rSource) and CharManager.hasFeat(ActorManager.getCreatureNode(rSource), CharManager.FEAT_DURABLE) then
		local nDurableMin = math.max(ActorManager5E.getAbilityBonus(rSource, "constitution"), 1) * 2;
		if nTotal < nDurableMin then
			rMessage.text = string.format("%s [DURABLE %+d]", rMessage.text, nDurableMin - nTotal);
			rMessage.diemodifier = rMessage.diemodifier + (nDurableMin - nTotal);
			nTotal = nDurableMin;
		else
			rMessage.text = rMessage.text .. " [DURABLE]";
		end
	end

	local nLevel = getContaminationLevel(rSource)
	if nLevel >= 2 then
		rRoll.nTotal = math.floor(ActionsManager.total(rRoll) / 2);
		rMessage.text = rMessage.text .. " [CONTAMINATION: " .. tonumber(nLevel) .."][HALF]"
	else
		rRoll.nTotal = ActionsManager.total(rRoll);
	end
	-- Deliver roll message
	Comm.deliverChatMessage(rMessage);

	-- Apply recovery
	if rRoll.sClassNode then
		rMessage.text = rMessage.text .. " [NODE:" .. rRoll.sClassNode .. "]";
	end
	rRoll.sDesc = rMessage.text;
	ActionDamage.notifyApplyDamage(nil, rSource, rRoll);
end
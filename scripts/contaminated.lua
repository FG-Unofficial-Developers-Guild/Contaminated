--  	Author: Ryan Hagelstrom
--	  	Copyright © 2022
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/
--
-- luacheck: globals onInit onClose decrementContaminated sumContamination cleanContaminationEffect updateEffect getContaminationLevel
-- luacheck: globals RRActionManager halfDamage performRoll onContamination customApplyDamage customMessageDamage customAddEffect
-- luacheck: globals customResetHealthNPC customResetHealth customParseEffect onRecovery calcDrakkenheimLunarDay calcDrakkenheimMonthVar
local addEffect = nil;
local parseEffects = nil;
local applyDamage = nil;
local messageDamage = nil;
local resetHealth = nil;
local resetHealthCombat2 = nil;

function onInit()
    addEffect = EffectManager.addEffect;
    parseEffects = PowerManager.parseEffects;
    applyDamage = ActionDamage.applyDamage;
    messageDamage = ActionDamage.messageDamage;
    resetHealth = CharManager.resetHealth;
    resetHealthCombat2 = CombatManager2.resetHealth;

    EffectManager.addEffect = customAddEffect;
    PowerManager.parseEffects = customParseEffect;
    ActionDamage.applyDamage = customApplyDamage;
    ActionDamage.messageDamage = customMessageDamage;
    CharManager.resetHealth = customResetHealth;
    CombatManager2.resetHealth = customResetHealthNPC;

    ActionsManager.registerResultHandler('contamination', onContamination);
    ActionsManager.registerResultHandler('recovery', onRecovery);
    if RRActionManager then
        RRActionManager.registerRollType('contamination');
    end

    table.insert(DataCommon.conditions, 'contamination');
    table.sort(DataCommon.conditions);

    CalendarManager.registerLunarDayHandler('Drakkenheim', calcDrakkenheimLunarDay);
    CalendarManager.registerMonthVarHandler('Drakkenheim', calcDrakkenheimMonthVar);
end

function onClose()
    EffectManager.addEffect = addEffect;
    PowerManager.parseEffects = parseEffects;
    ActionDamage.applyDamage = applyDamage;
    ActionDamage.messageDamage = messageDamage;
    CharManager.resetHealth = resetHealth;
    CombatManager2.resetHealth = resetHealthCombat2;
end

function decrementContaminated(rActor)
    local nodeCT = ActorManager.getCTNode(rActor);
    local nLevel = 0;
    for _, nodeEffect in ipairs(DB.getChildList(nodeCT, 'effects')) do
        if nodeEffect and type(nodeEffect) == 'databasenode' then
            local sEffect = DB.getValue(nodeEffect, 'label', '');
            local aEffectComps = EffectManager.parseEffect(sEffect);

            for i, sEffectComp in ipairs(aEffectComps) do
                local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
                if rEffectComp.type:lower() == 'contamination' then
                    if rEffectComp.mod == 5 and EffectManager5E.hasEffectCondition(rActor, 'Incapactiated') then
                        EffectManager.removeCondition(rActor, 'Incapactiated');
                    end

                    rEffectComp.mod = rEffectComp.mod - 1;
                    if rEffectComp.mod >= 1 then
                        if rEffectComp.mod > nLevel then
                            nLevel = rEffectComp.mod;
                        end
                        aEffectComps[i] = rEffectComp.type .. ': ' .. tostring(rEffectComp.mod);
                        sEffect = EffectManager.rebuildParsedEffect(aEffectComps);
                        updateEffect(nodeCT, nodeEffect, sEffect);
                    else
                        EffectManager.expireEffect(nodeCT, nodeEffect, 0);
                    end
                end
            end
        end
    end
    return nLevel;
end

function sumContamination(rActor, nContaminationLevel)
    local nSummed = nil;
    local nodeCT = ActorManager.getCTNode(rActor);
    local nodeEffectsList = DB.getChildList(nodeCT, 'effects');

    for _, nodeEffect in ipairs(nodeEffectsList) do
        local sEffect = DB.getValue(nodeEffect, 'label', '');
        local aEffectComps = EffectManager.parseEffect(sEffect);
        for i, sEffectComp in ipairs(aEffectComps) do
            local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
            if rEffectComp.type:upper() == 'CONTAMINATION' then
                rEffectComp.mod = rEffectComp.mod + nContaminationLevel;
                aEffectComps[i] = rEffectComp.type .. ': ' .. tostring(rEffectComp.mod);
                sEffect = EffectManager.rebuildParsedEffect(aEffectComps);
                updateEffect(nodeCT, nodeEffect, sEffect);
                nSummed = rEffectComp.mod;
            end
        end
    end
    return nSummed;
end

function cleanContaminationEffect(sUser, _, nodeCT, rNewEffect, bShowMsg)
    local nContaminationLevel = 0;
    local rTarget = ActorManager.resolveActor(nodeCT);
    local rSource = ActorManager.resolveActor(rNewEffect.sSource);
    local sOriginal = rNewEffect.sName;
    local aImmuneConditions = ActorManager5E.getConditionImmunities(rTarget, rSource);
    local aNewEffectComps = {};
    local aIgnoreComps = {};
    local bImmune = false;
    if StringManager.contains(aImmuneConditions, 'contamination') then
        bImmune = true;
    end
    local aEffectComps = EffectManager.parseEffect(rNewEffect.sName);
    for _, sEffectComp in ipairs(aEffectComps) do
        local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp);
        if rEffectComp.type:lower() == 'contamination' or rEffectComp.original:lower() == 'contamination' then
            if bImmune then
                table.insert(aIgnoreComps, sEffectComp);
            else
                if rEffectComp.mod == 0 then
                    rEffectComp.mod = 1;
                    sEffectComp = sEffectComp .. ': 1';
                end
                nContaminationLevel = rEffectComp.mod;
                table.insert(aNewEffectComps, sEffectComp:upper())
            end
        else
            table.insert(aNewEffectComps, sEffectComp);
        end
    end
    rNewEffect.sName = EffectManager.rebuildParsedEffect(aNewEffectComps);
    if next(aIgnoreComps) then
        if bShowMsg then
            local bSecret = ((rNewEffect.nGMOnly or 0) == 1);
            local sMessage;
            if rNewEffect.sName == '' then
                sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sOriginal,
                                         Interface.getString('effect_status_targetimmune'));
            else
                sMessage = string.format('%s [\'%s\'] -> [%s] [%s]', Interface.getString('effect_label'), sOriginal,
                                         Interface.getString('effect_status_targetpartialimmune'), table.concat(aIgnoreComps, ','));
            end
            if bSecret then
                EffectManager.message(sMessage, nodeCT, true);
            else
                EffectManager.message(sMessage, nodeCT, false, sUser);
            end
        end
    end

    return nContaminationLevel;
end

function updateEffect(nodeActor, nodeEffect, sLabel)
    DB.setValue(nodeEffect, 'label', 'string', sLabel);
    local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
    local sMessage = string.format('%s [\'%s\'] -> [%s]', Interface.getString('effect_label'), sLabel,
                                   Interface.getString('effect_status_updated'));
    EffectManager.message(sMessage, nodeActor, bGMOnly);
end

function getContaminationLevel(rActor)
    local nLevel = 0;
    local tContaminationEffects = EffectManager5E.getEffectsByType(rActor, 'CONTAMINATION');
    for _, rEffectComp in pairs(tContaminationEffects) do
        if rEffectComp.mod > nLevel then
            nLevel = rEffectComp.mod;
        end
    end
    return nLevel;
end

-- Parses the damage text and makes modifications to it so it prints out half damage correctly to the chat
function halfDamage(sDamage)
    local sNewDamage = sDamage:gsub('%s*%[TYPE:[^%]]*%]%s*', '');
    for sType in sDamage:gmatch('%[TYPE:[^%]]*%]') do
        local sParsedDamage = sType:match('%d+%)%]$'):gsub('%)%]$', '');
        local nClauseDamage = math.floor(tonumber(sParsedDamage) / 2);
        sType = sType:gsub('=%d+%)', '=' .. tostring(nClauseDamage) .. ')');
        sNewDamage = sNewDamage .. sType;
    end
    return sNewDamage;
end

-- mutation roll
function performRoll(rActor, nContamination, bGMOnly)
    local rRoll = {};
    rRoll.sType = 'contamination';
    rRoll.aDice = {'d6'};
    rRoll.nMod = 0;
    rRoll.nContamination = nContamination;
    rRoll.sDesc = '[CONTAMINATION: ' .. tostring(nContamination) .. '] ';
    rRoll.bSecret = bGMOnly;

    ActionsManager.performAction(nil, rActor, rRoll);
end

-- User will have to construct the mutation table themselfs (IP reasons), roll on it themselves for mutation and apply the result.
function onContamination(rSource, _, rRoll)
    if not Session.IsHost then
        return;
    end
    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
    local nTotal = ActionsManager.total(rRoll);
    if rRoll.nContamination and nTotal <= tonumber(rRoll.nContamination) then
        rMessage.text = rMessage.text .. ' -> [MUTATION]'
    end
    if rRoll.nContamination and (tonumber(rRoll.nContamination) == 6) then
        rMessage.text = rMessage.text .. ' [MONSTROUS TRANSFORMATION]';
    end
    Comm.deliverChatMessage(rMessage);
end

-- I think the intent of contamination: 4 is to take half and then appy whatever stuff in apply damage to that
-- so something like save for half... we do half damage, and then on save they get another half for a total of a quarter
-- This will also do 1/2 damage to all damage done by this source such as effects which could be ruled as spells
-- and will also do 1/2 damage to unarmed strikes
function customApplyDamage(rSource, rTarget, rRoll)
    local nLevel = getContaminationLevel(rSource);
    if nLevel >= 4 and rRoll.sType == 'damage' then
        rRoll.nTotal = math.floor(rRoll.nTotal / 2);
        rRoll.sDesc = halfDamage(rRoll.sDesc);
        rRoll.sDesc = rRoll.sDesc .. ' [CONTAMINATION: ' .. tostring(nLevel) .. ']';
    end
    applyDamage(rSource, rTarget, rRoll);
end

-- Need to set the damage chat text here since we can't do it in applyDamage easily because that function is such a cluster
function customMessageDamage(rSource, rTarget, rRoll)
    local sContamination = rRoll.sDesc:match('%[CONTAMINATION:%s*%d*]');

    if sContamination and rRoll.sType == 'damage' then
        rRoll.sResults = sContamination .. ' [HALF]' .. rRoll.sResults;
    end
    return messageDamage(rSource, rTarget, rRoll);
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
    if not nodeCT or not rNewEffect or not rNewEffect.sName then
        return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    end
    local nContaminated = nil;
    local nContaminationLevel = cleanContaminationEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    -- Immune casued an empty effect so ignore
    if rNewEffect.sName == '' then
        return;
    end
    if nContaminationLevel > 0 then
        local rActor = ActorManager.resolveActor(nodeCT);
        local bGMOnly = false;

        nContaminated = sumContamination(rActor, nContaminationLevel)
        if nContaminated then
            nContaminationLevel = nContaminated;
        end
        -- Level 5 target is Incapactiated
        if nContaminationLevel >= 5 and not EffectManager5E.hasEffectCondition(rActor, 'Incapactiated') then
            EffectManager.addCondition(rActor, 'Incapactiated');
        end
        if rNewEffect.nGMOnly == 1 then
            bGMOnly = true;
        end
        performRoll(rActor, nContaminationLevel, bGMOnly);
    end
    if not nContaminated then
        addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg);
    end
end

function customResetHealthNPC(nodeCT, bLong)
    if bLong then
        local bRested = false;
        local nodeChar = ActorManager.getCreatureNode(nodeCT);
        local rActor = ActorManager.resolveActor(nodeCT);
        local aEffectsByType = EffectManager5E.getEffectsByType(rActor, 'CONTAMINATION');
        if aEffectsByType and next(aEffectsByType) then
            for _, rEffectComp in pairs(aEffectsByType) do
                if rEffectComp.mod >= 3 then
                    local currentHealth = DB.getValue(nodeChar, 'wounds', 0);
                    resetHealthCombat2(nodeCT, bLong);
                    -- reset the health back to what it was before the rest
                    DB.setValue(nodeChar, 'wounds', 'number', currentHealth);
                    bRested = true;
                    break
                end
            end
            decrementContaminated(rActor);
        end
        if not bRested then
            resetHealthCombat2(nodeCT, bLong);
        end
    else
        resetHealthCombat2(nodeCT, bLong);
    end
end

-- Only want to disallow the HP factor of rest but the char still benfits from things like gaining back HD
function customResetHealth(nodeChar, bLong)
    local bRested = false;
    if bLong then
        local rActor = ActorManager.resolveActor(nodeChar);
        local aEffectsByType = EffectManager5E.getEffectsByType(rActor, 'CONTAMINATION');
        if aEffectsByType and next(aEffectsByType) then
            for _, rEffectComp in pairs(aEffectsByType) do
                if rEffectComp.mod >= 3 then
                    local currentHealth = DB.getValue(nodeChar, 'hp.wounds', 0);
                    resetHealth(nodeChar, bLong);
                    -- reset the health back to what it was before the rest
                    DB.setValue(nodeChar, 'hp.wounds', 'number', currentHealth);
                    bRested = true;
                    break
                end
            end
            decrementContaminated(rActor);
        end
        if not bRested then
            resetHealth(nodeChar, bLong);
        end
    else
        resetHealth(nodeChar, bLong);
    end
end

function customParseEffect(sPowerName, aWords)
    local effects = parseEffects(sPowerName, aWords);
    local i = 1;
    while aWords[i] do
        if StringManager.isWord(aWords[i], {'gain', 'gains'}) then
            local bContamination = true;
            local sLevel = '0';
            if StringManager.isWord(aWords[i + 1], {'1', 'one', 'another'}) then
                sLevel = '1';
            elseif StringManager.isWord(aWords[i + 1], {'2', 'two'}) then
                sLevel = '2';
            elseif StringManager.isWord(aWords[i + 1], {'3', 'three'}) then
                sLevel = '3';
            elseif StringManager.isWord(aWords[i + 1], {'4', 'four'}) then
                sLevel = '4';
            elseif StringManager.isWord(aWords[i + 1], {'5', 'five'}) then
                sLevel = '5';
            elseif StringManager.isWord(aWords[i + 1], {'6', 'six'}) then
                sLevel = '6';
            else
                bContamination = false;
            end
            if bContamination and StringManager.isWord(aWords[i + 2], {'level', 'levels'}) and
                StringManager.isWord(aWords[i + 3], 'of') and StringManager.isWord(aWords[i + 4], 'contamination') then
                local rContamination = {};
                rContamination.sName = 'CONTAMINATION: ' .. sLevel;
                rContamination.startindex = i;
                rContamination.endindex = i + 4;
                PowerManager.parseEffectsAdd(aWords, i, rContamination, effects);
            end
        end
        i = i + 1;
    end
    return effects;
end

-- This will conflict with other extensions but I doubt many if any are playing in this space
function onRecovery(rSource, _, rRoll)
    -- Get basic roll message and total
    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
    local nTotal = ActionsManager.total(rRoll);

    -- Handle minimum damage
    if nTotal < 0 and rRoll.aDice and #rRoll.aDice > 0 then
        rMessage.text = rMessage.text .. ' [MIN RECOVERY]';
        rMessage.diemodifier = rMessage.diemodifier - nTotal;
        nTotal = 0;
    end
    if ActorManager.isPC(rSource) and CharManager.hasFeat(ActorManager.getCreatureNode(rSource), CharManager.FEAT_DURABLE) then
        local nDurableMin = math.max(ActorManager5E.getAbilityBonus(rSource, 'constitution'), 1) * 2;
        if nTotal < nDurableMin then
            rMessage.text = string.format('%s [DURABLE %+d]', rMessage.text, nDurableMin - nTotal);
            rMessage.diemodifier = rMessage.diemodifier + (nDurableMin - nTotal);
            -- nTotal = nDurableMin; -- this is in 5E. nTotal getting set and not used seems like a bug
        else
            rMessage.text = rMessage.text .. ' [DURABLE]';
        end
    end

    local nLevel = getContaminationLevel(rSource)
    if nLevel >= 2 then
        rRoll.nTotal = math.floor(ActionsManager.total(rRoll) / 2);
        rMessage.text = rMessage.text .. ' [CONTAMINATION: ' .. tonumber(nLevel) .. '][HALF]';
    else
        rRoll.nTotal = ActionsManager.total(rRoll);
    end
    -- Deliver roll message
    Comm.deliverChatMessage(rMessage);

    -- Apply recovery
    if rRoll.sClassNode then
        rMessage.text = rMessage.text .. ' [NODE:' .. rRoll.sClassNode .. ']';
    end
    rRoll.sDesc = rMessage.text;
    ActionDamage.notifyApplyDamage(nil, rSource, rRoll);
end

-- Drakkenheim Calandar Support
function calcDrakkenheimLunarDay(nYear, nMonth, nDay)
    local nZellerYear = nYear;
    local nZellerMonth = nMonth
    if nMonth < 3 then
        nZellerYear = nZellerYear - 1;
        nZellerMonth = nZellerMonth + 12;
    end
    local nZellerDay = (nDay + math.floor(2.6 * (nZellerMonth + 1)) + nZellerYear + math.floor(nZellerYear / 4) +
                           (6 * math.floor(nZellerYear / 100)) + math.floor(nZellerYear / 400)) % 7;
    if nZellerDay == 0 then
        return 7;
    end
    return nZellerDay;
end

function calcDrakkenheimMonthVar(_, nMonth)
    if nMonth == 2 then
        local nYear = DB.getValue('calendar.current.year', 0);
        if (nYear % 400) == 0 then
            return 1;
        elseif (nYear % 100) == 0 then
            return 0;
        elseif (nYear % 4) == 0 then
            return 1;
        end
    end
    return 0;
end

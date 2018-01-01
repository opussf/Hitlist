HITLIST_MSG_VERSION = GetAddOnMetadata("Hitlist","Version");
HITLIST_MSG_ADDONNAME = "Hitlist";

-- Colours
COLOR_RED = "|cffff0000";
COLOR_GREEN = "|cff00ff00";
COLOR_BLUE = "|cff0000ff";
COLOR_PURPLE = "|cff700090";
COLOR_YELLOW = "|cffffff00";
COLOR_ORANGE = "|cffff6d00";
COLOR_GREY = "|cff808080";
COLOR_GOLD = "|cffcfb52b";
COLOR_NEON_BLUE = "|cff4d4dff";
COLOR_END = "|r";

Hitlist = {};
Hitlist.types = {[0]="player", [1]="building", [3]="NPC", [4]="pet", [5]="vehicle"};
Hitlist.inCombat = 0;
Hitlist.debug = false;
Hitlist.playerClass = {};    -- cache of player's class

function Hitlist_OnLoad()
	HitlistFrame:RegisterEvent("ADDON_LOADED");
	HitlistFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	HitlistFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
	HitlistFrame:RegisterEvent("PLAYER_REGEN_DISABLED");
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Hitlist.CHAT_MSG_SYSTEM);

	--register slash commands
	SLASH_HITLIST1 = "/hitlist";
	SLASH_HITLIST2 = "/hl";
	SlashCmdList["HITLIST"] = function(msg) Hitlist.command(msg); end
	GameTooltip:HookScript("OnTooltipSetUnit", Hitlist_HookSetUnit)
	
	Hitlist.WAS_DEFEATED_TEXT = "(.+) has defeated (.+) in a duel";
	Hitlist.HAS_FLED_TEXT = "(.+) has fled from (.+) in a duel";
end
function Hitlist.ADDON_LOADED()
	Hitlist.name = UnitName("player");
	Hitlist.realm = GetRealmName();
	
	if Hitlist_scores == nil then
		Hitlist_scores = {};
	end

	-- find or init the realm
	realmFound, playerFound = false, false;
	for k,v in pairs(Hitlist_scores) do
		if (k == Hitlist.realm) then
			realmFound = true;
			break;
		end
	end
	if not realmFound then
		Hitlist_scores[Hitlist.realm] = {};
	end

	-- find or init the player
	for k,v in pairs(Hitlist_scores[Hitlist.realm]) do
		if (k == Hitlist.name) then
			playerFound = true;
			break;
		end
	end
	if not playerFound then
		Hitlist_scores[Hitlist.realm][Hitlist.name] = {};
		Hitlist_scores[Hitlist.realm][Hitlist.name].class = {};
	end
	
	Hitlist.initCombatData();
	Hitlist.inCombat = 0;
	if (Hitlist.timerData == nil) then
		Hitlist.initTimerData();
	end
	
	Hitlist.pruneData();
end
function Hitlist.print(msg, showName)
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_RED..HITLIST_MSG_ADDONNAME.."> "..COLOR_END..msg;
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg );
end
function Hitlist.debugPrint(msg)
	if (Hitlist.debug) then
		Hitlist.print( "(debug) "..msg);
	end
end
function Hitlist.printStatus()
	Hitlist.print("Status Report");
	Hitlist.print("Version: "..HITLIST_MSG_VERSION);
	Hitlist.print("Memory usage: "..collectgarbage('count').." kB");
end
Hitlist.channelTable = {
	['guild'] = {['func'] = GetNumGuildMembers, ['chan'] = "GUILD"},
	['party'] = {['func'] = GetNumPartyMembers, ['chan'] = "PARTY"},
	['raid'] = {['func'] = GetNumRaidMembers, ['chan'] = "RAID"},
	['bg'] = {['fund'] = function return 1 end, ['chan']= "BATTLEGROUND"},
}
function Hitlist.printScores( param )
	timerStr = "- in the last "..Hitlist.secondsToTime(time() - Hitlist.timerData.init).." (%s-%s): ";
	timerCount = 0;
	totals = {["W"] = 0, ["L"] = 0};
	for class, vals in pairs(Hitlist.timerData.class) do
		timerStr = timerStr .. vals.localClass ..": ".. vals.killed .."-".. vals.killedby .."  ";
		totals.W = totals.W + vals.killed;  totals.L = totals.L + vals.killedby;
		timerCount = timerCount + 1;
	end
	timerStr = string.format(timerStr, totals.W, totals.L);

	totals = {["W"] = 0, ["L"] = 0};
	outStr = "My Lifetime W-L record (%s-%s) per class: ";
	for class, vals in pairs(Hitlist_scores[Hitlist.realm][Hitlist.name].class) do
		outStr = outStr .. vals.localClass ..": ".. vals.killed .."-".. vals.killedby .."  ";
		totals.W = totals.W + vals.killed;  totals.L = totals.L + vals.killedby;
	end
	outStr = string.format(outStr, totals.W, totals.L);
	
	if (param) then
		if (Hitlist.channelTable[param]) then
			Hitlist.print("Knows channel");
			if (Hitlist.channelTable[param].func() > 0) then
				SendChatMessage( outStr, Hitlist.channelTable[param].chan );
				if (timerCount > 0) then
					SendChatMessage( timerStr, Hitlist.channelTable[param].chan );
				end
			end
		elseif (param ~= "") then
			SendChatMessage( outStr, "WHISPER", nil, param);
			if (timerCount > 0) then
				SendChatMessage( timerStr, "WHISPER", nil, param );
			end
		else
			Hitlist.print(outStr);
			if (timerCount > 0) then
				Hitlist.print(timerStr);
			end
		end
	else
--		Hitlist.print(outStr);
	end
end
function Hitlist.initCombatData()
	Hitlist.combatData = {};    -- table is recorded as key is source data is target.  [player] damaged target
end
function Hitlist.initTimerData()
	-- timerData will mirror Hitlist_scores
	Hitlist.timerData = {};
	Hitlist.timerData.init = time();
	Hitlist.timerData.class = {};
end
function Hitlist.PLAYER_REGEN_DISABLED(...)
--function Hitlist.combatStart()
	Hitlist.debugPrint("Combat started");
	Hitlist.initCombatData();
	Hitlist.inCombat = 1
end
function Hitlist.OnUNIT_DIED( victimGUID, victim )
	-- combatData[wasDamagedBy][didDamage].counter
	local victimType = (tonumber(victimGUID:sub(5,5), 16) % 8);
	if (victimType == 0) then    -- player
		Hitlist.debugPrint("Player "..victim.." ("..victimGUID..") died.");
		for hurt, hitBy in pairs(Hitlist.combatData) do
			if (hurt == victim) then
				Hitlist.debugPrint("The killed was hurt by:");
				for hitter, countData in pairs(hitBy) do
					Hitlist.debugPrint(" -"..hitter.." is a "..Hitlist.playerClass[hitter].englishClass);
					if (countData.used == 0) then
						Hitlist.debugPrint(victim.." killed by "..hitter.." has NOT been recorded yet.");
						myScores = Hitlist_scores[Hitlist.realm][Hitlist.name];
						if (victim == Hitlist.name) then    -- you were killed by these
							classInfo = Hitlist.playerClass[hitter];
							Hitlist.recordKilledBy( myScores, hitter, classInfo );
							Hitlist.recordKilledBy( Hitlist.timerData, hitter, classInfo );
							countData.used = 1;
							score = myScores[hitter].killed .."-"..myScores[hitter].killedby;
							classScore = myScores.class[classInfo.englishClass].killed .."-".. myScores.class[classInfo.englishClass].killedby;
							Hitlist.print(hitter.." killed you. ("..score..") "..classInfo.localClass .." ("..classScore..")");
						else    -- you killed these
							classInfo = Hitlist.playerClass[victim];
							Hitlist.recordKilled( myScores, victim, classInfo );
							Hitlist.recordKilled( Hitlist.timerData, victim, classInfo );
							countData.used = 1;
							score = myScores[victim].killed .."-"..myScores[victim].killedby;
							classScore = myScores.class[classInfo.englishClass].killed .."-".. myScores.class[classInfo.englishClass].killedby;
							Hitlist.print("you killed "..victim.." ("..score..") "..classInfo.localClass .." ("..classScore..")");
						end
					else
						Hitlist.debugPrint(victim.." killed by "..hitter.." has been recorded.");
					end
				end
			end
		end
	end
end
function Hitlist.recordKilledBy( record, hitter, classInfo )
	if (record[hitter]) then
		record[hitter].killedby = record[hitter].killedby + 1;
	else
		record[hitter] = {};
		record[hitter].killed = 0;
		record[hitter].killedby = 1;
	end
	record[hitter].lastFight = time();
	if (record.class[classInfo.englishClass]) then
		record.class[classInfo.englishClass].killedby = record.class[classInfo.englishClass].killedby + 1;
	else
		record.class[classInfo.englishClass] = {};
		record.class[classInfo.englishClass].killed = 0;
		record.class[classInfo.englishClass].killedby = 1;
		record.class[classInfo.englishClass].localClass = classInfo.localClass;
	end
end
function Hitlist.recordKilled( record, victim, classInfo )
	if (record[victim]) then
		record[victim].killed = record[victim].killed + 1;    -- increment killed counter
	else
		record[victim] = {};
		record[victim].killed = 1;
		record[victim].killedby = 0;
	end
	record[victim].lastFight = time();
	if (record.class[classInfo.englishClass]) then
		record.class[classInfo.englishClass].killed = record.class[classInfo.englishClass].killed + 1;
	else
		record.class[classInfo.englishClass] = {};
		record.class[classInfo.englishClass].killed = 1;
		record.class[classInfo.englishClass].killedby = 0;
		record.class[classInfo.englishClass].localClass = classInfo.localClass;
	end
end
function Hitlist.PLAYER_REGEN_ENABLED()
	Hitlist.debugPrint("Combat ended");
	Hitlist.inCombat = 0;
	if (Hitlist.debug) then
		hitCount = 0;
		for hurt, hitBy in pairs(Hitlist.combatData) do
			hitCount = hitCount + 1;
			Hitlist.debugPrint(hurt.." was hurt by:");
		end
		if (hitCount == 0) then
			Hitlist.debugPrint("No PvP took place");
		end
	end
end
function Hitlist.damageDone( sourceName, sourceGUID, sourceFlags, targetName, targetGUID, targetFlags )
	-- combatData[wasDamagedBy][didDamage].counter
	local sourceType = (tonumber(sourceGUID:sub(5,5), 16) % 8);
	local targetType = (tonumber(targetGUID:sub(5,5), 16) % 8);
	
	if (Hitlist.inCombat) then
		if (sourceName) and (targetName) then
			if (sourceName == Hitlist.name) or (targetName == Hitlist.name) then    -- attacker or attacked is you
				Hitlist.debugPrint(sourceName .." ("..Hitlist.types[sourceType]..") hurt "..targetName.." ("..Hitlist.types[targetType]..")");

				if (sourceType == 0) and (sourceType == targetType) and (targetName ~= nil) then    -- both are players
					Hitlist.debugPrint("PvP");
					if (Hitlist.combatData[targetName] == nil) then
						Hitlist.combatData[targetName] = {};
						Hitlist.debugPrint("Target: "..targetName.." was added.");
					end
					Hitlist.recordPlayerClass( targetName, targetGUID );
					Hitlist.recordPlayerClass( sourceName, sourceGUID );
					if (Hitlist.combatData[targetName][sourceName]) then
						Hitlist.combatData[targetName][sourceName].counter = Hitlist.combatData[targetName][sourceName].counter + 1;
					else
						Hitlist.combatData[targetName][sourceName] = {};
						Hitlist.combatData[targetName][sourceName].counter = 1;
					end
					Hitlist.combatData[targetName][sourceName].used = 0;

					Hitlist.debugPrint(sourceName.." added to "..targetName);
				end
			end
		end -- nil check
	end 
end
function Hitlist.COMBAT_LOG_EVENT_UNFILTERED(...)
	-- http://www.wowwiki.com/API_COMBAT_LOG_EVENT
	_, _, Hitlist.event = select(1, ...);  -- frame, ts, event
--	if (strfind(event, "DAMAGE")) then
	if (strsub(Hitlist.event, -6) == "DAMAGE") then
		local srcGUID, srcName, srcFlags, _, targetGUID, targetName, targetFlags = select(5, ...);
		--Hitlist.print("src:"..srcName.."("..srcGUID.."::"..srcFlags..")");
		--Hitlist.print("trg:"..targetName.."("..targetGUID.."::"..targetFlags..")");
		Hitlist.damageDone( srcName, srcGUID, srcFlags, targetName, targetGUID, targetFlags );
	elseif (Hitlist.event == "UNIT_DIED") then
		local _, _, _, _, targetGUID, targetName = select(5, ...);
		--Hitlist.print("Killed:"..targetName.."("..targetGUID..")");
		Hitlist.OnUNIT_DIED( targetGUID, targetName );
	end
end
function Hitlist.CHAT_MSG_SYSTEM(frame, event, message, ...)
	Hitlist.debugPrint(event..":"..message);

	_, _, winner, loser = string.find(message, Hitlist.WAS_DEFEATED_TEXT);
	if (not winner) then
		_, _, loser, winner = string.find(message, Hitlist.HAS_FLED_TEXT);
	end
	if (winner and loser) then
		Hitlist.debugPrint("winner: "..winner..". Loser: "..loser);
		myScores = Hitlist_scores[Hitlist.realm][Hitlist.name];
		-- playerClass only has class info if damage was exchanged.
		if (loser == Hitlist.name and Hitlist.playerClass[winner]) then  -- you were killed by winner (or fled)
			classInfo = Hitlist.playerClass[winner];
			Hitlist.debugPrint("winner class: "..classInfo.englishClass);
			Hitlist.recordKilledBy( myScores, winner, classInfo );
			Hitlist.recordKilledBy( Hitlist.timerData, winner, classInfo );
			local score = myScores[winner].killed .."-"..myScores[winner].killedby;
			local classScore = myScores.class[classInfo.englishClass].killed .."-".. myScores.class[classInfo.englishClass].killedby;
			Hitlist.print(winner.." killed you. ("..score..") "..classInfo.localClass .." ("..classScore..")");
		elseif (winner == Hitlist.name and Hitlist.playerClass[loser]) then  -- you won, or the loser fled
			classInfo = Hitlist.playerClass[loser];
			Hitlist.debugPrint("loser class: "..classInfo.englishClass);
			Hitlist.recordKilled( myScores, loser, classInfo );
			Hitlist.recordKilled( Hitlist.timerData, loser, classInfo );
			score = myScores[loser].killed .."-"..myScores[loser].killedby;
			classScore = myScores.class[classInfo.englishClass].killed .."-".. myScores.class[classInfo.englishClass].killedby;
			Hitlist.print("you killed "..loser.." ("..score..") "..classInfo.localClass .." ("..classScore..")");
		end
	end
end
function Hitlist.parseCmd(msg)
	if msg then
		local a,b,c = strfind(msg, "(%S+)");  --contiguous string of non-space characters (start, end, firstword, rest of str)
		if a then
			return c, strsub(msg, b+2);
		else
			return "";
		end
	end
end
-- slash function handle
function Hitlist.command(msg)
	--cmd will be nothing
	local cmd, param = Hitlist.parseCmd(msg);
	
	if (cmd == "status") then
		Hitlist.printStatus();
	elseif (cmd == "debug") then
		Hitlist.debug = true;
		Hitlist.print("Debug On");
	elseif (cmd == "normal") then
		Hitlist.debug = false;
		Hitlist.print("Debug Off");
	elseif (cmd == "reset") then
		Hitlist.print("Hitlist timer reset.");
		Hitlist.initTimerData();
	else
		Hitlist.printScores( cmd );
	end
end
function Hitlist_HookSetUnit(arg1, arg2)
	local Name = GameTooltip:GetUnit();
	local Realm = ""; 
	if UnitName("mouseover") == Name then 
		_, Realm = UnitName("mouseover"); 
		if not Realm then 
			Realm = GetRealmName(); 
		end
	end
	if (Name) then
		nameRealm = Name.."-"..Realm;		
		if (Realm == Hitlist.realm) then
			nameRealm = Name;
		end
		myScores = Hitlist_scores[Hitlist.realm][Hitlist.name];
		if myScores[nameRealm] then
			score = myScores[nameRealm].killed .."-"..myScores[nameRealm].killedby;
			GameTooltip:AddLine("Hitlist: "..score);
		end
	end
end
function Hitlist.recordPlayerClass( playerName, playerGUID )
	if (Hitlist.playerClass[playerName]) then
	else
		Hitlist.playerClass[playerName] = {};
		localClass, englishClass, localRace, englishRace, gender = GetPlayerInfoByGUID( playerGUID );
		Hitlist.debugPrint( localClass..":"..localRace..":"..gender );
		Hitlist.playerClass[playerName].localClass = localClass;
		Hitlist.playerClass[playerName].englishClass = englishClass;
		Hitlist.debugPrint("Class recorded");
	end
end
function Hitlist.secondsToTime(secsIn)
	-- Blizzard's SecondsToTime() function cannot be printed into Chat.  Has bad escape codes.
	local day, hour, minute, sec = 0,0,0,0;
	day = string.format("%i", (secsIn / 86400)) * 1;	-- LUA integer conversion
	if day < 0 then return ""; end
	secsIn = secsIn - (day * 86400);
	hour = string.format("%i", (secsIn / 3600)) * 1;
	if (day > 0) then
		return string.format("%i Day %i Hour", day, hour);
	end
	secsIn = secsIn - (hour * 3600);
	minute = string.format("%i", (secsIn / 60)) * 1;
	if (hour > 0) then
		return string.format("%ih %im", hour, minute);
	end
	sec = secsIn - (minute * 60);
	if (minute>0) then
		return string.format("%im %is", minute, sec);
	end
	return string.format("%is", sec);
end
function Hitlist.pruneData()
	local cutOff = 90 * 86400;    -- 90 days
	cutOff = time() - cutOff;
	for player, vals in pairs(Hitlist_scores[Hitlist.realm][Hitlist.name]) do
		if (player ~= "class") then
			if (vals.lastFight == nil) then
				vals.lastFight = time()
			end
			if (vals.lastFight < cutOff) then
				Hitlist.print(player.."  pruned.");
				Hitlist_scores[Hitlist.realm][Hitlist.name][player] = nil;
			end
		end
	end
end

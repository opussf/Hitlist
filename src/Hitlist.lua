HITLIST_MSG_VERSION = GetAddOnMetadata("Hitlist","version")
HITLIST_MSG_ADDONNAME = "Hitlist"

-- Colours
COLOR_RED = "|cffff0000"
COLOR_GREEN = "|cff00ff00"
COLOR_BLUE = "|cff0000ff"
COLOR_PURPLE = "|cff700090"
COLOR_YELLOW = "|cffffff00"
COLOR_ORANGE = "|cffff6d00"
COLOR_GREY = "|cff808080"
COLOR_GOLD = "|cffcfb52b"
COLOR_NEON_BLUE = "|cff4d4dff"
COLOR_END = "|r"

Hitlist = {}
--Hitlist.types = {[0]="player", [1]="building", [3]="NPC", [4]="pet", [5]="vehicle"}
Hitlist.inCombat = 0
Hitlist.playerClass = {}    -- cache of player's class
Hitlist.playerFlag = 0x0400
Hitlist.WAS_DEFEATED_TEXT = "(.+) has defeated (.+) in a duel"
Hitlist.HAS_FLED_TEXT     = "(.+) has fled from (.+) in a duel"


-- stored data
Hitlist_scores = {}

function Hitlist.OnLoad()
	HitlistFrame:RegisterEvent("ADDON_LOADED")
	--HitlistFrame:RegisterEvent("VARIABLES_LOADED")
	HitlistFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	HitlistFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	HitlistFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

	--register slash commands
	SLASH_HITLIST1 = "/hitlist";
	SLASH_HITLIST2 = "/hl";
	SlashCmdList["HITLIST"] = function(msg) Hitlist.command(msg); end

	-- Chat system hook
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", Hitlist.CHAT_MSG_SYSTEM)
	GameTooltip:HookScript( "OnTooltipSetUnit", Hitlist.HookSetUnit )
end
function Hitlist.ADDON_LOADED( )
	Hitlist.name = UnitName("player")
	Hitlist.realm = GetRealmName()
	Hitlist.fullname = Hitlist.name.."-"..Hitlist.realm

	-- find or init the realm in the storage table
	if( not Hitlist_scores[Hitlist.realm] ) then
		Hitlist_scores[Hitlist.realm] = {}
	end
	if( not Hitlist_scores[Hitlist.realm][Hitlist.name] ) then
		Hitlist_scores[Hitlist.realm][Hitlist.name] = {}
		Hitlist_scores[Hitlist.realm][Hitlist.name].class = {}
	end

	Hitlist.initCombatData()
	Hitlist.initTimerData()
	Hitlist.pruneData()
end
function Hitlist.PLAYER_REGEN_DISABLED()
	if( Hitlist.debug ) then
		Hitlist.print( "Combat started" )
	end
	Hitlist.initCombatData()
	Hitlist.inCombat = true
end
function Hitlist.PLAYER_REGEN_ENABLED()
	if( Hitlist.debug ) then
		Hitlist.print( "Combat ended" )
	end
	Hitlist.inCombat = nil
	--[[
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
	]]
end
function Hitlist.COMBAT_LOG_EVENT_UNFILTERED( ... )
	-- http://www.wowwiki.com/API_COMBAT_LOG_EVENT
	_, _, Hitlist.event = select( 1, ... )  -- frame, ts, event

	--Hitlist.print( Hitlist.event )
	if( strsub( Hitlist.event, -6 ) == "DAMAGE" ) then
		local srcGUID, srcName, srcFlags, _, targetGUID, targetName, targetFlags = select( 5, ... )
		--Hitlist.print("src:"..srcName.."("..srcGUID.."::"..srcFlags..")")
		--Hitlist.print("trg:"..targetName.."("..targetGUID.."::"..targetFlags..")")
		Hitlist.damageDone( srcGUID, srcName, srcFlags, targetGUID, targetName, targetFlags )
	elseif( Hitlist.event == "UNIT_DIED" ) then
		local _, _, _, _, targetGUID, targetName, targetFlags = select( 5, ... )
		--Hitlist.print("Killed:"..targetName.."("..targetGUID.." flags: "..targetFlags..")" )
		Hitlist.OnUNIT_DIED( targetGUID, targetName, targetFlags )
	end
end
function Hitlist.CHAT_MSG_SYSTEM( frame, event, message, ... )
	--Hitlist.print( "CHAT_MSG_SYSTEM: "..event.."::"..message )
	_, _, winner, loser = string.find( message, Hitlist.WAS_DEFEATED_TEXT )
	if( not winner ) then
		_, _, loser, winner = string.find( message, Hitlist.HAS_FLED_TEXT )
	end
	if( winner and loser ) then  -- does not make sense if the winner or loser cannot be found
		--print( "winner: "..winner.." loser: "..loser )
		myScores = Hitlist_scores[Hitlist.realm][Hitlist.name]
		-- playerClass only has class info if damage was exchanged.
		if( loser == Hitlist.name and Hitlist.playerClass[winner] ) then  -- you were killed by winner (or fled)
			classInfo = Hitlist.playerClass[winner]
			--print( "winner class: "..classInfo.englishClass )
			Hitlist.recordKilledBy( myScores, winner, classInfo )
			Hitlist.recordKilledBy( Hitlist.timerData, winner, classInfo )
			local score = myScores[winner].killed.."-"..myScores[winner].killedby
			local classScore = myScores.class[classInfo.englishClass].killed.."-"..myScores.class[classInfo.englishClass].killedby
			Hitlist.print( winner.." killed you. ("..score..") "..classInfo.localClass.." ("..classScore..")" )
		elseif( winner == Hitlist.name and Hitlist.playerClass[loser] ) then  -- you won, or the loser fled
			classInfo = Hitlist.playerClass[loser]
			Hitlist.recordKilledBy( myScores, loser, classInfo, true ) -- loser is the victim here
			Hitlist.recordKilledBy( Hitlist.timerData, loser, classInfo, true )
			score = myScores[loser].killed.."-"..myScores[loser].killedby
			classScore = myScores.class[classInfo.englishClass].killed.."-"..myScores.class[classInfo.englishClass].killedby
			Hitlist.print( "You killed "..loser.." ("..score..") "..classInfo.localClass .." ("..classScore..")" )
		end
	end
end
-- END   EVENTS --
-- START FUNCTIONS --
function Hitlist.print( msg, showName )
	-- print to the chat frame
	-- set showName to false to suppress the addon name printing
	if (showName == nil) or (showName) then
		msg = COLOR_RED..HITLIST_MSG_ADDONNAME.."> "..COLOR_END..msg;
	end
	DEFAULT_CHAT_FRAME:AddMessage( msg );
end
function Hitlist.isPlayer( flags )
	return( ( bit.band( flags, Hitlist.playerFlag ) ~= 0 ) and true )
end
function Hitlist.damageDone( sourceGUID, sourceName, sourceFlags, targetGUID, targetName, targetFlags )
	-- combatData[wasDamagedBy][didDamage].counter
	-- http://wowwiki.wikia.com/wiki/UnitFlag
	-- 0x0500 tests if the source is both a player type (0x400) and controlled by a player (0x100)
	sourceIsPlayer = Hitlist.isPlayer( sourceFlags )
	targetIsPlayer = Hitlist.isPlayer( targetFlags )

	if( Hitlist.inCombat ) then  -- you are in combat
		if( sourceName and targetName ) then  -- both a source and a target name are given
			--Hitlist.print( "Damage done while in combat. "..sourceName.." hit "..targetName )
			if( sourceName == Hitlist.name or targetName == Hitlist.name ) then  -- attacker or attacked is you

				if( sourceIsPlayer and targetIsPlayer ) then
					--Hitlist.print( sourceName .." ("..sourceFlags..") hurt "..targetName.." ("..targetFlags..")" )
					if( not Hitlist.combatData[targetName] ) then
						Hitlist.combatData[targetName] = {}
						--Hitlist.print( "Target: "..targetName.." was added." )
					end
					if( Hitlist.combatData[targetName][sourceName] ) then
						Hitlist.combatData[targetName][sourceName].counter = Hitlist.combatData[targetName][sourceName].counter + 1
					else
						Hitlist.combatData[targetName][sourceName] = { ["counter"] = 1 }
					end
					Hitlist.combatData[targetName][sourceName].used = 0

					Hitlist.recordPlayerClass( targetName, targetGUID );
					Hitlist.recordPlayerClass( sourceName, sourceGUID );
				end
			end
		end
	end
end
function Hitlist.recordPlayerClass( playerName, playerGUID )
	if( not Hitlist.playerClass[playerName] ) then
		Hitlist.playerClass[playerName] = {}
		localClass, englishClass, localRace, englishRace, gender = GetPlayerInfoByGUID( playerGUID )
		--Hitlist.debugPrint( localClass..":"..localRace..":"..gender );
		Hitlist.playerClass[playerName].localClass = localClass
		Hitlist.playerClass[playerName].englishClass = englishClass
		--Hitlist.debugPrint("Class recorded");
	end
end
function Hitlist.initCombatData()
	-- combatData[wasDamagedBy][whoDidDamage].counter
	Hitlist.combatData = {}  -- table is recorded as key is source data is target.  [player] damaged target
end
function Hitlist.initTimerData()
	-- timerData will mirror Hitlist_scores
	-- class["Warlock"] = { ["killed"], ["killedby"], ["localClass"] }
	Hitlist.timerData = {}
	Hitlist.timerData.init = time()
	Hitlist.timerData.class = {}
end
function Hitlist.OnUNIT_DIED( victimGUID, victimName, victimFlags )
	--
	--print( "--> OnUNIT_DIED( "..victimGUID..", "..victimName..", "..victimFlags.." )" )
	victimIsPlayer = Hitlist.isPlayer( victimFlags )
	--victimIsPlayer = ( bit.band( victimFlags, Hitlist.playerFlag ) ~= 0 ) and true or nil
	if( victimIsPlayer ) then
		--Hitlist.print( "Player "..victimName.." ("..victimGUID..") died." )
		for hurt, hitBy in pairs( Hitlist.combatData ) do
			if( hurt == victimName ) then
				--Hitlist.print( "The killed was hurt by:" )
				for hitter, countData in pairs( hitBy ) do
					--Hitlist.print( " -"..hitter.." is a (class)" )
					if( countData.used == 0 ) then
						--Hitlist.print( victimName.." killed by "..hitter.." has NOT been recorded yet." )
						myScores = Hitlist_scores[Hitlist.realm][Hitlist.name]
						if( victimName == Hitlist.name ) then  -- you were killed by these
							classInfo = Hitlist.playerClass[hitter]
							Hitlist.recordKilledBy( myScores, hitter, classInfo )
							Hitlist.recordKilledBy( Hitlist.timerData, hitter, classInfo )
							countData.used = 1 -- record that this death has been recorde
							-- output the 'score'
							score = myScores[hitter].killed.."-"..myScores[hitter].killedby
							classScore = myScores.class[classInfo.englishClass].killed.."-"..myScores.class[classInfo.englishClass].killedby
							Hitlist.print( hitter.." killed you. ("..score..") "..classInfo.localClass.." ("..classScore..")" )
						else  -- you killed these
							classInfo = Hitlist.playerClass[victimName]
							Hitlist.recordKilledBy( myScores, victimName, classInfo, true ) -- true isVictim flag
							Hitlist.recordKilledBy( Hitlist.timerData, victimName, classInfo, true )
							countData.used = 1
							score = myScores[victimName].killed.."-"..myScores[victimName].killedby
							classScore = myScores.class[classInfo.englishClass].killed.."-"..myScores.class[classInfo.englishClass].killedby
							Hitlist.print( "You killed "..victimName.." ("..score..") "..classInfo.localClass .." ("..classScore..")" )
						end
					else  -- death already recorded
						-- Hitlist.print( victim.." killed by "..hitter.." has been recorded." )
					end
				end
			end
		end
	end
end
function Hitlist.recordKilledBy( record, player, classInfo, isVictim )
	-- updates the record to reflect being killed by player
	-- record: (table) - struct to update
	-- player: (string / key) - who to record
	-- classInfo: (table) - class info table
	-- isVictim: (boolean) - is the player the victim?
	if( record[player] ) then
		record[player].killed   = record[player].killed   + (isVictim and 1 or 0)
		record[player].killedby = record[player].killedby + (isVictim and 0 or 1)
	else
		record[player] = {
			["killed"]   = (isVictim and 1 or 0),
			["killedby"] = (isVictim and 0 or 1)
		}
	end
	record[player].lastFight = time()
	if( record.class[classInfo.englishClass] ) then
		record.class[classInfo.englishClass].killed   = record.class[classInfo.englishClass].killed   + (isVictim and 1 or 0)
		record.class[classInfo.englishClass].killedby = record.class[classInfo.englishClass].killedby + (isVictim and 0 or 1)
	else
		record.class[classInfo.englishClass] = {
				["killed"]   = (isVictim and 1 or 0),
				["killedby"] = (isVictim and 0 or 1),
				["localClass"] = classInfo.localClass
		}
	end
end
-- Command / interface section
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
Hitlist.commandList = {}
function Hitlist.printHelp()
	Hitlist.print( HITLIST_MSG_ADDONNAME.." version: "..HITLIST_MSG_VERSION )
	Hitlist.print( "Use: /hitlist or /hl for these commands:" )
	for cmd, info in pairs( Hitlist.commandList ) do
		Hitlist.print( string.format( "-- %s %s -> %s",
				cmd, info.help[1], info.help[2] ) )
	end
end
Hitlist.commandList["help"] = {
		["func"] = Hitlist.printHelp,
		["help"] = { "", "Print this help" }
}
Hitlist.commandList["reset"] = {
		["func"] = function() Hitlist.print( "Hitlist timer reset."); Hitlist.initTimerData(); end,
		["help"] = { "", "Reset the timer data." }
}
function Hitlist.printStatus()
	Hitlist.print("Status Report");
	Hitlist.print("Version: "..HITLIST_MSG_VERSION);
	Hitlist.print("Memory usage: "..collectgarbage('count').." kB");
end
Hitlist.commandList["status"] = {
		["func"] = Hitlist.printStatus,
		["help"] = { "", "Show addon status" }
}
function Hitlist.printScores( param )
	timerStr = "Since "..date( "%H:%M:%S", Hitlist.timerData.init ).." (%s-%s): "
	timerCount = 0
	totals = { ["W"] = 0, ["L"] = 0 }
	for class, vals in pairs( Hitlist.timerData.class ) do
		timerStr = timerStr .. vals.localClass ..": ".. vals.killed .."-"..vals.killedby.."  "
		totals.W = totals.W + vals.killed
		totals.L = totals.L + vals.killedby
		timerCount = timerCount + 1
	end
	timerStr = string.format( timerStr, totals.W, totals.L )

	totalStr = "My lifetime W-L record (%s-%s) per class: "
	totals = { ["W"] = 0, ["L"] = 0 }
	for class, vals in pairs( Hitlist_scores[Hitlist.realm][Hitlist.name].class ) do
		totalStr = totalStr .. vals.localClass ..": "..vals.killed .."-"..vals.killedby .. "  "
		totals.W = totals.W + vals.killed
		totals.L = totals.L + vals.killedby
	end
	totalStr = string.format( totalStr, totals.W, totals.L )

	if( param ) then
		if( param == "guild" and IsInGuild() ) then
			chatChannel = "GUILD"
		elseif( param == "party" and IsInGroup() ) then
			chatChannel = "PARTY"
		elseif( param == "instance" and IsInGroup( LE_PARTY_CATEGORY_INSTANCE ) ) then
			chatChannel = "INSTANCE"
		elseif( param == 'raid' and IsInRaid() ) then
			chatChannel = "RAID"
		elseif( param ~= "" ) then
			chatChannel = "WHISPER"
			toWhom = param
		end

		if( chatChannel ) then
			SendChatMessage( totalStr, chatChannel, nil, toWhom )  -- toWhom will be nil for most
			if( timerCount > 0 ) then
				SendChatMessage( timerStr, chatChannel, nil, toWhom )
			end
		else
			Hitlist.print(totalStr);
			if (timerCount > 0) then
				Hitlist.print(timerStr);
			end
		end
	end
end
Hitlist.commandList["print"] = {
		["func"] = Hitlist.printScores,
		["help"] = { "[guild|party|raid|bg|<playerName>]", "Print score to channel or player." }
}
-- slash function handle
function Hitlist.command(msg)
	--cmd will be nothing
	local cmd, param = Hitlist.parseCmd( msg )
	cmd = string.lower( cmd )
	local cmdFunc = Hitlist.commandList[cmd]
	if cmdFunc then
		cmdFunc.func( param )
	else
		Hitlist.printHelp()
		--Hitlist.printScores( cmd )
	end
end
function Hitlist.HookSetUnit(arg1, arg2)
	local Name = GameTooltip:GetUnit()
	local Realm = ""
	if UnitName("mouseover") == Name then
		_, Realm = UnitName("mouseover");
		if not Realm then
			Realm = GetRealmName();
		end
	end
	if (Name) then
		nameRealm = Name.."-"..Realm;
		if( Realm == Hitlist.realm ) then
			nameRealm = Name
		end
		myScores = Hitlist_scores[Hitlist.realm][Hitlist.name]
		if myScores[nameRealm] then
			score = myScores[nameRealm].killed .."-"..myScores[nameRealm].killedby
			GameTooltip:AddLine( "Hitlist: "..score )
		end
	end
end
function Hitlist.pruneData()
	local cutOff = 90 * 86400  -- 90 days
	local cutOff = 120
	cutOff = time() - cutOff
	for player, vals in pairs( Hitlist_scores[Hitlist.realm][Hitlist.name] ) do
		if( player ~= "class" ) then
			if( vals.lastFight == nil ) then
				vals.lastFight = time()  -- if last fight time not recorded, record it so that it can be pruned later
			end
			if( vals.lastFight < cutOff ) then
				Hitlist.print( player.."  pruned." )
				Hitlist_scores[Hitlist.realm][Hitlist.name][player] = nil
			end
		end
	end
end

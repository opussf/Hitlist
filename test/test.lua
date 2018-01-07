#!/usr/bin/env lua

addonData = { ["version"] = "1.0",
}

require "wowTest"

test.outFileName = "testOut.xml"

HitlistFrame = CreateFrame()
GameTooltip = CreateFrame( "GameTooltip", "tooltip" )

-- require the file to test
package.path = "../src/?.lua;'" .. package.path
require "Hitlist"

function test.before()
	Hitlist_scores = {}
	Hitlist.OnLoad()
	Hitlist.ADDON_LOADED( {} )
end
function test.after()
	-- always take the player out of combat for the next test
	Hitlist.PLAYER_REGEN_ENABLED()
	Hitlist.playerClass = {}
end

function test.test_has_playerName()
	assertEquals( "testPlayer", Hitlist.name )
end
function test.test_has_realmName()
	assertEquals( "testRealm", Hitlist.realm )
end
function test.test_has_fullname()
	assertEquals( "testPlayer-testRealm", Hitlist.fullname )
end
function test.test_Hitlist_scores_created()
	-- this is the main storage table
	assertTrue( Hitlist_scores )
end
function test.test_Hitlist_scores_realm()
	assertTrue( Hitlist_scores.testRealm )
end
function test.test_Hitlist_scores_player()
	assertTrue( Hitlist_scores.testRealm.testPlayer )
end
function test.test_Hitlist_scores_playerClass()
	assertTrue( Hitlist_scores.testRealm.testPlayer.class )
end
function test.test_Hitlist_combatData_created()
	assertTrue( Hitlist.combatData )
end
function test.test_Hitlist_timerData_created()
	assertTrue( Hitlist.timerData )
end
function test.test_Hitlist_combatStart()
	Hitlist.PLAYER_REGEN_DISABLED()
	assertTrue( Hitlist.inCombat )
end
function test.test_Hitlist_combatEnd()
	Hitlist.PLAYER_REGEN_ENABLED()
	assertIsNil( Hitlist.inCombat )
end
function test.test_Hitlist_combatEvent_inCombat_PvE_SWING_DAMAGE_toCreature_combatData_noDataRecorded()
	-- combatData[wasDamagedBy] should still be nil
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Creature-0-3131-0-13377-2544-00004ACCAE", "Southern Sand Crawler", 68136, 0x0 )
	assertIsNil( Hitlist.combatData["Southern Sand Crawler"] )
end
function test.test_Hitlist_combatEvent_inCombat_PvE_SWING_DAMAGE_fromCreature_combatData_noDataRecorded()
	-- combatData[wasDamagedBy] should still be nil
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Creature-0-3131-0-13377-2544-00004ACCAE", "Southern Sand Crawler", 68136, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )
	assertIsNil( Hitlist.combatData["testPlayer"] )
end

function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_setsTarget()
	-- sets the damage source in Hitlist.combatData
	-- pass a swing_damage event while in combat
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertTrue( Hitlist.combatData["otherPlayer-otherRealm"] )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_setsSource()
	-- sets the damage source in Hitlist.combatData
	-- pass a swing_damage event while in combat
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertTrue( Hitlist.combatData["otherPlayer-otherRealm"]["testPlayer"] )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_setsCounter()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertEquals( 1, Hitlist.combatData["otherPlayer-otherRealm"]["testPlayer"].counter )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_setsUsed()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertEquals( 0, Hitlist.combatData["otherPlayer-otherRealm"]["testPlayer"].used )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_classRecorded_source()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertTrue( Hitlist.playerClass["testPlayer"] )
	assertEquals( "Warlock", Hitlist.playerClass["testPlayer"].localClass )
	assertEquals( "Warlock", Hitlist.playerClass["testPlayer"].englishClass )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_combatData_classRecorded_target()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertTrue( Hitlist.playerClass["otherPlayer-otherRealm"] )
	assertEquals( "Warlock", Hitlist.playerClass["otherPlayer-otherRealm"].localClass )
	assertEquals( "Warlock", Hitlist.playerClass["otherPlayer-otherRealm"].englishClass )
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_endCombat_targetLoses()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "UNIT_DIED", "", "0000000000", nil, 0x80000000, 0x80000000,
			"Player-96-0651D446" ,"otherPlayer-otherRealm", 0x512, 0x0 )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"], "Player should be recorded in Hitlist_scored" )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"], "killed player should have a table." )
	assertEquals( 1, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killed )
	assertEquals( 0, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killedby )
--	UNIT_DIED,0000000000000000,nil,0x80000000,0x80000000,Player-96-0651D446,"Whisperingi-Velen",0x512,0x0
end
function test.test_Hitlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_endCombat_targetWins()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )

	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "UNIT_DIED", "", "0000000000", nil, 0x80000000, 0x80000000,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"] )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"] )
	assertEquals( 0, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killed )
	assertEquals( 1, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killedby )
end
function test.test_Histlist_CombatEvent_inCombat_PvP_SWING_DAMAGE_endCombat_targetWins_timerDataRecorded()
	Hitlist.initTimerData()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )

	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "UNIT_DIED", "", "0000000000", nil, 0x80000000, 0x80000000,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )
	assertTrue( Hitlist.timerData.class["Warlock"] )
	assertEquals( 1, Hitlist.timerData.class["Warlock"].killedby )
	assertEquals( 0, Hitlist.timerData.class["Warlock"].killed )
end
function test.test_Hitlist_CombatEvent_inCombat_SWING_DAMAGE_combatData_neitherAreYou()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	assertIsNil( Hitlist.combatData["otherPlayer-otherRealm"] )
end
function test.test_isPlayer_ArmyOfDead()
	assertIsNil( Hitlist.isPlayer( 8468 ) )  -- 0x2114 (Guardian, Player control_player, Friendly, Party )
end
function test.test_isPlayer_Self()
	assertTrue( Hitlist.isPlayer( 1297 ) )  -- 0x511
end
function test.test_isPlayer_Totem()
	assertIsNil( Hitlist.isPlayer( 8466 ) )
end
function test.test_RecordKilledBy_hitter_noPreviousRecord_struct()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertTrue( struct[hitter] )
end
function test.test_RecordKilledBy_hitter_noPreviousRecord_killed()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertEquals( 0, struct[hitter].killed )
end
function test.test_RecordKilledBy_hitter_noPreviousRecord_killedby()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertEquals( 1, struct[hitter].killedby )
end
function test.test_RecordKilledBy_hitter_previousRecord_killed()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	struct[hitter] = { ["killed"] = 0, ["killedby"] = 1 }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertEquals( 0, struct[hitter].killed )
end
function test.test_RecordKilledBy_hitter_previousRecord_killedby()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	struct[hitter] = { ["killed"] = 0, ["killedby"] = 1 }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertEquals( 2, struct[hitter].killedby )
end
function test.test_RecordKilledBy_hitter_lastFight()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class" }
	struct[hitter] = { ["killed"] = 0, ["killedby"] = 1 }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertTrue( struct[hitter].lastFight )
end
function test.test_RecordKilledBy_class_noPreviousRecord()
	-- makes sure that the record is created
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class", ["localClass"] = "lc" }
	Hitlist.recordKilledBy( struct, hitter, classInfo )
	assertTrue( struct.class["class"] )
	assertEquals( 0, struct.class.class.killed )
	assertEquals( 1, struct.class.class.killedby )
	assertEquals( "lc", struct.class.class.localClass )
end
function test.test_RecordKilledBy_isVictim()
	struct = { ["class"] = { } }
	hitter = "hitter"
	classInfo = { ["englishClass"] = "class", ["localClass"] = "lc" }
	Hitlist.recordKilledBy( struct, hitter, classInfo, true )
	assertTrue( struct.class["class"] )
	assertEquals( 1, struct.class.class.killed, "this player should be recorded as killed" )
	assertEquals( 0, struct.class.class.killedby, "this player should not be recorded as killedby" )
	assertEquals( "lc", struct.class.class.localClass )
end
------------------------------------------
-- Chat msg system
function test.test_ChatMsgSystem_defeated()
	Hitlist.initTimerData()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )
	Hitlist.CHAT_MSG_SYSTEM( "frame", "event", "testPlayer has defeated otherPlayer-otherRealm in a duel" )

	assertTrue( Hitlist_scores["testRealm"]["testPlayer"], "Player should be recorded in Hitlist_scored" )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"], "killed player should have a table." )
	assertEquals( 1, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killed )
	assertEquals( 0, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killedby )
end
function test.test_ChatMsgSystem_fled()
	Hitlist.initTimerData()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )

	Hitlist.CHAT_MSG_SYSTEM( "frame", "event", "testPlayer has fled from otherPlayer-otherRealm in a duel" )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"], "Player should be recorded in Hitlist_scored" )
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"], "killed player should have a table." )
	assertEquals( 0, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killed )
	assertEquals( 1, Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"].killedby )
end
------------------------------------------
-- Commands
function test.test_command()
	Hitlist.command( "" )
end
function test.test_command_help()
	Hitlist.command( "help" )
end
function test.test_command_reset()
	Hitlist.command( "reset" )
end
function test.test_command_status()
	Hitlist.command( "status" )
end
function test.test_command_printScores()
	Hitlist.command( "print" )
end
------------------------------------------
-- Print Scores
function test.test_printScores_01()
	Hitlist.initTimerData()
	Hitlist.PLAYER_REGEN_DISABLED()
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-3661-06DB0FE4", "testPlayer", 1297, 0,
			"Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0 )
	Hitlist.COMBAT_LOG_EVENT_UNFILTERED( "frame", 0, "SWING_DAMAGE", "unknown", "Player-96-0651D446", "otherPlayer-otherRealm", 1298, 0x0,
			"Player-3661-06DB0FE4", "testPlayer", 1297, 0 )

	Hitlist.CHAT_MSG_SYSTEM( "frame", "event", "testPlayer has fled from otherPlayer-otherRealm in a duel" )
	Hitlist.printScores( "party" )
end
------------------------------------------
-- Print Scores
function test.initPruneData()
	Hitlist_scores = {
		["testRealm"] = {
			["testPlayer"] = {
				["class"] = {
					["ROGUE"] = {
						["localClass"] = "Rogue",
						["killedby"] = 2,
						["killed"] = 1,
					},
				},
				["otherPlayer-otherRealm"] = {
					["lastFight"] = time(),
					["killedby"] = 2,
					["killed"] = 0,
				},
				["oldPlayer-oldRealm"] = {
					["lastFight"] = time() - (89 * 86400),
					["killedby"] = 2,
					["killed"] = 0,
				},
				["tooOldPlayer-tooOldRealm"] = {
					["lastFight"] = time() - (95 * 86400),
					["killedby"] = 2,
					["killed"] = 0,
				},
				["notimePlayer-notimeRealm"] = {
					["killedby"] = 2,
					["killed"] = 0,
				},
			},
		},
	}
end
function test.test_pruneData_keepsYoungRecord()
	test.initPruneData()
	Hitlist.pruneData()
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["otherPlayer-otherRealm"] )
end
function test.test_pruneData_keepsOldRecord()
	test.initPruneData()
	Hitlist.pruneData()
	assertTrue( Hitlist_scores["testRealm"]["testPlayer"]["oldPlayer-oldRealm"] )
end
function test.test_pruneData_removesTooOldRecord()
	test.initPruneData()
	Hitlist.pruneData()
	assertIsNil( Hitlist_scores["testRealm"]["testPlayer"]["tooOldPlayer-tooOldRealm"] )
end
function test.test_pruneData_adds_lastFight_ifnotthere()
	test.initPruneData()
	Hitlist.pruneData()
	assertEquals( time(), Hitlist_scores["testRealm"]["testPlayer"]["notimePlayer-notimeRealm"]["lastFight"] )
end


--	SWING_DAMAGE,Player-3661-06DB0FE4,"Airwin-Hyjal",0x511,0x0,Creature-0-3131-0-13377-2544-00004ACCAE,"Southern Sand Crawler",0x10a28,0x0,0000000000000000,0000000000000000,0,0,0,0,-1,0,0,0,0.00,0.00,0,426177,424932,1,0,0,0,1,nil,nil

test.run()

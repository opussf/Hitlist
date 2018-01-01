# Hitlist

[![Build Status](https://travis-ci.org/opussf/Hitlist.svg?branch=master)](https://travis-ci.org/opussf/Hitlist)
[Hitlist on CurseForge.com](https://www.curseforge.com/wow/addons/hitlist)

Welcome to Hitlist.

Hitlist records PvP scores for individual characters.

This was born from talking to a few people that PvP a lot more than I do.

Use /hitlist or /hl.
```
/hl reset     - will reset the kill counter
/hl party
/hl raid
/hl guild
/hl bg        - send hl info to Battleground
/hl <name>    - send hl info to party, raid, guild or player
/hl status
```

Programming by:
: Sistersally @ hyjal

Ideas from:
: Frigobar @ dunemaul
: Pudingpants @ hyjal
: Xildar @ hyjal
: Noski @ Ner'zhul

Testing by:
: Xildar @ hyjal
: Noski @ Ner'zhul

Change Log:
```
0.9     - 4.2 fixes.  Thanks Blizzard
0.8     - Cataclysm fixes
0.7     - Cleaned up some event tracking
        - Enabled listening for duel results to track duels.
		  (Should support fleeing as well)
0.6     - Fixed for Cataclysm (4.x)
0.5     - Added lastcombat timestamp to data, and prune data (hard code to 90 days).
0.4     - Timer data.  Records W-L record for a period of time (say a battleground)
		- added person SecondsToTime function since Blizzards is still broken
		- added totals to report line
0.3     - No major list of players
0.2		- Output Score in GameTooltip
		- Class score keeping
0.1		- Initial coding - simple PvP player damages player scores
```

How to score this:
* Data collection starts when player goes into combat.
* Any player that causes damage to you, and you die (before leaving combat) gets credit for a kill.
* Any player that you do damage to, and dies before you exit combat, you get credit for a kill.


Bugs / Issues / Features
: F0001 - Removed list of players on /hl command - 0.3
: F0002 - Better report of Wins : Losses - 0.3
: F0003 - /hl takes guild, party, or raid for report
: F0004 - timer data.  enough changes were done for this to bump to 0.4
: F0005 - totals in report line - 0.4
: B0001 - ToolTip was not showing data for toons from the same realm as the player
      - found and fixed in 0.2
: B0002 - Timer data was reset when leaving a BG - Fixed - 0.4
: F0006 - Command to show the top (3) players killed, and who killed you.


To Do:
: Figure out pets and add them into the mix.
: On pet damage, who is owner of pet?

-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local _tImportState = {};

function onTabletopInit()
	ImportNPCManagerRWI.initImportState = initImportState;
	local sLabel = Interface.getString("import_npc_mode_fm");
	ImportUtilityManager.registerImportMode("npc", "MCDM", sLabel, ImportNPCManagerRWI.importFleeMortals);
end

function importFleeMortals(sStats, sDesc)
	-- Track state information
	ImportNPCManagerRWI.initImportState(sStats, sDesc);

	-- Assume name, Challenge, and Role on Line 1
	ImportNPCManagerRWI.importHelperNameChallengeRole();

	-- Assume size/type/alignment/XP on Line 2
	ImportNPCManagerRWI.importHelperSizeTypeAlignmentXp();
	
	-- Assume AC on Line 3, HP on Line 4, and Speed on Line 5
	ImportNPCManagerRWI.importHelperACHPSpeed();

	-- Assume ability headers on Line 6, and ability scores/bonuses on Line 7
	ImportNPCManagerRWI.importHelperAbilities();
	
	-- Assume the following optional fields in the following order:
	--		Saving throws
	--		Skills
	--		Damage Vulnerabilities, 
	--		Damage Resistances
	--		Damage Immunities, 
	--		Condition Immunities
	--		Senses
	--		Languages
	--		Challenge
	ImportNPCManagerRWI.importHelperOptionalFields();
	
	-- Assume NPC actions appear next with the following headers: (Assume Traits until a header found)
	--		Traits, Actions, Bonus Actions, Reactions, Legendary Actions, Lair Actions
	ImportNPCManagerRWI.importHelperActions();

	-- Update Description by adding the statblock text as well
	ImportNPCManagerRWI.finalizeDescription();
	
	-- Open new record window and matching campaign list
	ImportUtilityManager.showRecord("npc", _tImportState.node);
end

-- Assumes name is on next line
function importHelperNameChallengeRole()
	-- Name
	ImportNPCManagerRWI.nextImportLine();

	local sName, sChallenge, sRole = _tImportState.sActiveLine:match("(.+) CR ([%d/]+) (%w+)")
	DB.setValue(_tImportState.node, "name", "string", sName);
	DB.setValue(_tImportState.node, "cr", "string", sChallenge);
	DB.setValue(_tImportState.node, "role", "string", sRole);

	-- Header
	ImportNPCManagerRWI.addStatOutput(string.format("<h>%s</h>", _tImportState.sActiveLine));
	
	-- Token
	ImportUtilityManager.setDefaultToken(_tImportState.node);
end

-- Assumes size/type/alignment/XP on next line; and of the form "<size> <type> (<sub1>, <sub2>), <alignment> <xp> XP"
function importHelperSizeTypeAlignmentXp()
	-- Example:Huge Elemental (Earth, Water), Any Alignment 13,000 XP
	ImportNPCManagerRWI.nextImportLine();
	if (_tImportState.sActiveLine or "") ~= "" then
		local sSize, sType, sAlignment, sXP = _tImportState.sActiveLine:match("(%w+) ([^%(,]+ ?%(?[^%)]*%)?), ([^%d]+) ([%d,]+) XP");
		sXP = sXP:gsub(",","");

		DB.setValue(_tImportState.node, "size", "string", sSize);
		DB.setValue(_tImportState.node, "type", "string", sType);
		DB.setValue(_tImportState.node, "alignment", "string", sAlignment);
		DB.setValue(_tImportState.node, "xp", "number", tonumber(sXP));

		ImportNPCManagerRWI.addStatOutput(string.format("<p><b><i>%s</i></b></p>", _tImportState.sActiveLine));
	end
end

-- Assumes AC/HP/Speed on next 3 lines in the following formats:
-- 		"Armor Class <ac> <actext>"
--		"Hit Points <hp> <hd>"
--		"Speed <speed>"
function importHelperACHPSpeed()
	local tMidOutput = {};

	-- Example: Armor Class 22 (natural armor)
	ImportNPCManagerRWI.nextImportLine(); -- Line 3
	if (_tImportState.sActiveLine or "") ~= "" then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sAC = tWords[3] or "";
		local sACText = table.concat(tWords, " ", 4) or "";

		DB.setValue(_tImportState.node, "ac", "number", sAC);
		DB.setValue(_tImportState.node, "actext", "string", sACText);
		table.insert(tMidOutput, string.format("<b>Armor Class</b> %s %s", sAC, sACText));
	end
	
	-- Example: Hit Points 464 (32d12 + 256)	
	ImportNPCManagerRWI.nextImportLine(); -- Line 4
	if (_tImportState.sActiveLine or "") ~= "" then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sHP = tWords[3] or "";
		local sHD = table.concat(tWords, " ", 4) or "";

		DB.setValue(_tImportState.node, "hp", "number", sHP);
		DB.setValue(_tImportState.node, "hd", "string", sHD);	
		table.insert(tMidOutput, string.format("<b>Hit Points</b> %s %s", sHP, sHD));
	end
	
	-- Example: Speed 50 ft., swim 50 ft.
	ImportNPCManagerRWI.nextImportLine(); -- Line 5
	if (_tImportState.sActiveLine or "") ~= "" then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sSpeed = table.concat(tWords, " ", 2) or "";

		DB.setValue(_tImportState.node, "speed", "string", sSpeed);
		table.insert(tMidOutput, string.format("<b>Speed</b> %s", sSpeed));
	end

	if #tMidOutput > 0 then
		ImportNPCManagerRWI.addStatOutput(string.format("<p>%s</p>", table.concat(tMidOutput, "&#13;")));
	end
end

-- Assumes ability headers on next line, and ability scores/bonuses on following line
function importHelperAbilities()
	-- Check next line for ability list
	ImportNPCManagerRWI.nextImportLine(); -- Line 6

	-- Check for short ability list
	local sSTR, sDEX, sCON, sINT, sWIS, sCHA;
	local sSTRBonus, sDEXBonus, sCONBonus, sINTBonus, sWISBonus, sCHABonus;
	if StringManager.trim(_tImportState.sActiveLine or "") == "STR" then
		ImportNPCManagerRWI.nextImportLine(); -- Line 7
		local tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sSTR = tAbilityWords[1] or "";
		sSTRBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");

		ImportNPCManagerRWI.nextImportLine(2); -- Line 9
		tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sDEX = tAbilityWords[1] or "";
		sDEXBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");

		ImportNPCManagerRWI.nextImportLine(2); -- Line 11
		tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sCON = tAbilityWords[1] or "";
		sCONBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");

		ImportNPCManagerRWI.nextImportLine(2); -- Line 13
		tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sINT = tAbilityWords[1] or "";
		sINTBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");

		ImportNPCManagerRWI.nextImportLine(2); -- Line 15
		tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sWIS = tAbilityWords[1] or "";
		sWISBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");

		ImportNPCManagerRWI.nextImportLine(2); -- Line 17
		tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);
		sCHA = tAbilityWords[1] or "";
		sCHABonus = (tAbilityWords[2] or ""):match("[+-]?%d+");
	else
		local tWords = StringManager.splitWords(_tImportState.sActiveLine);
		if #tWords == 6 and (tWords[1] == "STR") then
			ImportNPCManagerRWI.nextImportLine(); -- Line 7
			local tAbilityWords = StringManager.splitWords(_tImportState.sActiveLine);

			sSTR = tAbilityWords[1] or "";
			sSTRBonus = (tAbilityWords[2] or ""):match("[+-]?%d+");
			sDEX = tAbilityWords[3] or "";
			sDEXBonus = (tAbilityWords[4] or ""):match("[+-]?%d+");
			sCON = tAbilityWords[5] or "";
			sCONBonus = (tAbilityWords[6] or ""):match("[+-]?%d+");
			sINT = tAbilityWords[7] or "";
			sINTBonus = (tAbilityWords[8] or ""):match("[+-]?%d+");
			sWIS = tAbilityWords[9] or "";
			sWISBonus = (tAbilityWords[10] or ""):match("[+-]?%d+");
			sCHA = tAbilityWords[11] or "";
			sCHABonus = (tAbilityWords[12] or ""):match("[+-]?%d+");
		end
	end
	if not sSTR then
		ImportNPCManagerRWI.nextImportLine(-1);
		return;
	end

	DB.setValue(_tImportState.node, "abilities.strength.score", "number", sSTR);
	DB.setValue(_tImportState.node, "abilities.dexterity.score", "number", sDEX);
	DB.setValue(_tImportState.node, "abilities.constitution.score", "number", sCON);
	DB.setValue(_tImportState.node, "abilities.wisdom.score", "number", sWIS);
	DB.setValue(_tImportState.node, "abilities.intelligence.score", "number", sINT);
	DB.setValue(_tImportState.node, "abilities.charisma.score", "number", sCHA);

	DB.setValue(_tImportState.node, "abilities.strength.bonus", "number", sSTRBonus);
	DB.setValue(_tImportState.node, "abilities.dexterity.bonus", "number", sDEXBonus);
	DB.setValue(_tImportState.node, "abilities.constitution.bonus", "number", sCONBonus);
	DB.setValue(_tImportState.node, "abilities.wisdom.bonus", "number", sWISBonus);
	DB.setValue(_tImportState.node, "abilities.intelligence.bonus", "number", sINTBonus);
	DB.setValue(_tImportState.node, "abilities.charisma.bonus", "number", sCHABonus);	
	
	ImportNPCManagerRWI.addStatOutput("<table>");
	ImportNPCManagerRWI.addStatOutput("<tr>");
	ImportNPCManagerRWI.addStatOutput("<td><b>STR</b></td>");
	ImportNPCManagerRWI.addStatOutput("<td><b>DEX</b></td>");
	ImportNPCManagerRWI.addStatOutput("<td><b>CON</b></td>");
	ImportNPCManagerRWI.addStatOutput("<td><b>INT</b></td>");
	ImportNPCManagerRWI.addStatOutput("<td><b>WIS</b></td>");
	ImportNPCManagerRWI.addStatOutput("<td><b>CHA</b></td>");
	ImportNPCManagerRWI.addStatOutput("</tr>");
	ImportNPCManagerRWI.addStatOutput("<tr>");
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sSTR or "", sSTRBonus or ""));
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sDEX or "", sDEXBonus or ""));
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sCON or "", sCONBonus or ""));
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sINT or "", sINTBonus or ""));
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sWIS or "", sWISBonus or ""));
	ImportNPCManagerRWI.addStatOutput(string.format("<td>%s (%s)</td>", sCHA or "", sCHABonus or ""));
	ImportNPCManagerRWI.addStatOutput("</tr>");
	ImportNPCManagerRWI.addStatOutput("</table>");
end

-- Assume the following optional fields in the following order:
--		Saving throws
--		Skills
--		Damage Vulnerabilities, 
--		Damage Resistances
--		Damage Immunities, 
--		Condition Immunities
--		Senses
--		Languages
--		Challenge
function importHelperOptionalFields()
	local tSpecialOutput = {};

	ImportNPCManagerRWI.nextImportLine(); -- Line 8
	local sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);

	-- Example: Saving Throws Dex +10, Con +16, Wis +11, Cha +15
	if sSimpleLine and sSimpleLine:match("^savingthrows") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sSavingThrows = table.concat(tWords, " ", 3) or "";

		DB.setValue(_tImportState.node, "savingthrows", "string", sSavingThrows);		   
		table.insert(tSpecialOutput, string.format("<b>Saving Throws</b> %s", sSavingThrows));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end
	
	-- Example: Skills Insight +11, Perception +19
	if sSimpleLine and sSimpleLine:match("^skills") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sSkills = table.concat(tWords, " ", 2) or "";

		DB.setValue(_tImportState.node, "skills", "string", sSkills);		   
		table.insert(tSpecialOutput, string.format("<b>Skills</b> %s", sSkills));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end	

	-- Example: Damage Vulnerabilities cold, fire, lightning
	if sSimpleLine and sSimpleLine:match("^damagevulnerabilities") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sDamageVulnerabilities = table.concat(tWords, " ", 3) or "";

		DB.setValue(_tImportState.node, "damagevulnerabilities", "string", sDamageVulnerabilities);
		table.insert(tSpecialOutput, string.format("<b>Damage Vulnerabilities</b> %s", sDamageVulnerabilities));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end	  
	
	-- Example: Damage Resistances cold, fire, lightning
	if sSimpleLine and sSimpleLine:match("^damageresistances") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sDamageResistances = table.concat(tWords, " ", 3) or "";

		DB.setValue(_tImportState.node, "damageresistances", "string", sDamageResistances);		   
		table.insert(tSpecialOutput, string.format("<b>Damage Resistances</b> %s", sDamageResistances));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end	  
	
	-- Example: Damage Immunities poison; bludgeoning, piercing, and slashing that is nonmagical
	if sSimpleLine and sSimpleLine:match("^damageimmunities") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sDamageImmunities = table.concat(tWords, " ", 3) or "";

		DB.setValue(_tImportState.node, "damageimmunities", "string", sDamageImmunities);		   
		table.insert(tSpecialOutput, string.format("<b>Damage Immunities</b> %s", sDamageImmunities));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end	  

	-- Example: Condition Immunities poison; bludgeoning, piercing, and slashing that is nonmagical
	if sSimpleLine and sSimpleLine:match("^conditionimmunities") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sConditionImmunities = table.concat(tWords, " ", 3) or "";

		DB.setValue(_tImportState.node, "conditionimmunities", "string", sConditionImmunities);		   
		table.insert(tSpecialOutput, string.format("<b>Condition Immunities</b> %s", sConditionImmunities));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end   

	-- Example: Senses truesight 120 ft., passive Perception 29
	if sSimpleLine and sSimpleLine:match("^senses") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sSenses = table.concat(tWords, " ", 2) or "";

		DB.setValue(_tImportState.node, "senses", "string", sSenses);		   
		table.insert(tSpecialOutput, string.format("<b>Senses</b> %s", sSenses));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end  
	
	-- Example: Languages all, telepathy 120 ft.
	if sSimpleLine and sSimpleLine:match("^languages") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sLanguages = table.concat(tWords, " ", 2) or "";

		DB.setValue(_tImportState.node, "languages", "string", sLanguages);		   
		table.insert(tSpecialOutput, string.format("<b>Languages</b> %s", sLanguages or ""));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end
	
	-- Example: Challenge 26 (90,000 XP) Proficiency Bonus +8
	if sSimpleLine and sSimpleLine:match("^challenge") then
		local tWords = StringManager.splitTokens(_tImportState.sActiveLine);
		local sCR = tWords[2] or "";
		local sXPText = (tWords[3] or ""):match("[%d,]+") or "";

		DB.setValue(_tImportState.node, "cr", "string", sCR);
		DB.setValue(_tImportState.node, "xp", "number", sXPText:gsub(",", "")); -- Remove all non-numeric characters (commas)
		table.insert(tSpecialOutput, string.format("<b>Challenge</b> %s (%s XP)", sCR, sXPText));

		ImportNPCManagerRWI.nextImportLine();
		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
	end
	
	ImportNPCManagerRWI.addStatOutput(string.format("<p>%s</p>", table.concat(tSpecialOutput, "&#13;")));
end

function importHelperActions()
	while _tImportState.sActiveLine do
 		sSimpleLine = StringManager.simplify(_tImportState.sActiveLine);
		
		-- Look for a section header
		if sSimpleLine:match("^traits$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("traits");

		elseif sSimpleLine:match("^bonusactions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("bonusactions");
			ImportNPCManagerRWI.addStatOutput("<h>Bonus Actions</h>");

		elseif sSimpleLine:match("^actions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("actions");
			ImportNPCManagerRWI.addStatOutput("<h>Actions</h>");

		elseif sSimpleLine:match("^reactions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("reactions");
			ImportNPCManagerRWI.addStatOutput("<h>Reactions</h>");

		elseif sSimpleLine:match("^legendaryactions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("legendaryactions");
			ImportNPCManagerRWI.addStatOutput("<h>Legendary Actions</h>");

		elseif sSimpleLine:match("^villainactions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("legendaryactions");
			ImportNPCManagerRWI.addStatOutput("<h>Villain Actions</h>");

		elseif sSimpleLine:match("^lairactions$") then
			ImportNPCManagerRWI.finalizeAction();
			ImportNPCManagerRWI.setActionMode("lairactions");
			ImportNPCManagerRWI.addStatOutput("<h>Lair Actions</h>");

		else
			-- NOTE: DAD 2022-04-13 John wants us to only allow a period and not a colon. This forces an 
			-- exact syntax but make sure that we don't inadvertantly change a : to a period because that 
			-- is the syntax used for stuff like 3/day: Spell1, Spell2

			-- Look for a feature heading. It should be proper cased and end in a period
			-- If it is multiple words, then each word should begin with a capitalization.
			local sHeading, sRemainder = _tImportState.sActiveLine:match("([^.!]+[.!])%s(.*)")
			if ImportNPCManagerRWI.isActionHeading(sHeading) then
				ImportNPCManagerRWI.finalizeAction();
				ImportNPCManagerRWI.setActionData(sHeading, sRemainder);
			else
				ImportNPCManagerRWI.appendActionDesc(_tImportState.sActiveLine);
			end
		end

		ImportNPCManagerRWI.nextImportLine();
	end

	-- Finalize all actions
	ImportNPCManagerRWI.finalizeAction();
end

--
--	Import state identification and tracking
--

function isActionHeading(s)
	if not s then
		return false;
	end

	local sHeading = s;
	
	sHeading = sHeading:gsub(" of ", " Of ");
	sHeading = sHeading:gsub(" with ", " With ");
	sHeading = sHeading:gsub(" and ", " And ");
	sHeading = sHeading:gsub(" the ", " The ");
	sHeading = sHeading:gsub(" to ", " To ");
	sHeading = sHeading:gsub(" in ", " In ");
	sHeading = sHeading:gsub(" on ", " On ");
	sHeading = sHeading:gsub(" a ", " A ");
	sHeading = sHeading:gsub(" an ", " An ");
	sHeading = sHeading:gsub(" from ", " From ");
	sHeading = sHeading:gsub(" after ", " After ");
	sHeading = sHeading:gsub(" before ", " Before ");
	-- handle possessive titles
	sHeading = sHeading:gsub("\'s ", "'S ");
	
	if sHeading == StringManager.capitalizeAll(sHeading) then
		return true;
	elseif s:match("Recharges after") then
		return true;
	end
	return false;		
end

function initImportState(sStatBlock, sDesc)
	_tImportState = {};

	local sCleanStats = ImportUtilityManager.cleanUpText(sStatBlock);
	_tImportState.nLine = 0;
	_tImportState.tLines = ImportUtilityManager.parseFormattedTextToLines(sCleanStats);
	_tImportState.sActiveLine = "";

	_tImportState.sDescription = ImportUtilityManager.cleanUpText(sDesc);
	_tImportState.tStatOutput = {};

	_tImportState.sActionMode = "traits";
	_tImportState.sActionName = "";
	_tImportState.tActionDesc = {};

	local sRootMapping = LibraryData.getRootMapping("npc");
	_tImportState.node = DB.createChild(sRootMapping);
end

function nextImportLine(nAdvance)
	_tImportState.nLine = _tImportState.nLine + (nAdvance or 1);
	_tImportState.sActiveLine = _tImportState.tLines[_tImportState.nLine];
end

function addStatOutput(s)
	table.insert(_tImportState.tStatOutput, s);
end

function finalizeDescription()
	DB.setValue(_tImportState.node, "text", "formattedtext", _tImportState.sDescription .. table.concat(_tImportState.tStatOutput));
end

function setActionMode(s)
	_tImportState.sActionMode = s;
end

function setActionData(sName, sDesc)
	_tImportState.sActionName = sName;
	_tImportState.tActionDesc = {};
	if (sDesc or "") ~= "" then
		table.insert(_tImportState.tActionDesc, sDesc);
	end
end

function appendActionDesc(s)
	if (s or "") ~= "" then
		table.insert(_tImportState.tActionDesc, s);
	end
end

function finalizeAction()
	if (_tImportState.sActionName or "") ~= "" then
		local nodeGroup = DB.createChild(_tImportState.node, _tImportState.sActionMode);
		local node = DB.createChild(nodeGroup);
		if _tImportState.sActionName:match("%.$") then
			DB.setValue(node, "name", "string", _tImportState.sActionName:sub(1, -2));
		else
			DB.setValue(node, "name", "string", _tImportState.sActionName);
		end
		DB.setValue(node, "desc", "string", table.concat(_tImportState.tActionDesc, "\n"));
		local sOutputDesc = string.format("<p><b><i>%s</i></b> %s</p>", _tImportState.sActionName, table.concat(_tImportState.tActionDesc, "</p><p>"));
		ImportNPCManagerRWI.addStatOutput(sOutputDesc);

	elseif #(_tImportState.tActionDesc) > 0 then
		local sOutputDesc = string.format("<p>%s</p>", table.concat(_tImportState.tActionDesc, "</p><p>"));
		ImportNPCManagerRWI.addStatOutput(sOutputDesc);

	else
		return;
	end

	_tImportState.sActionName = "";
	_tImportState.tActionDesc = {};
end

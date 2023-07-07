-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

local initImportStateOriginal;
local importHelperSizeTypeAlignmentOriginal;
local appendActionDescOriginal;
local bIsFleeMortals;

function onTabletopInit()
	local sLabel = Interface.getString("import_npc_mode_fm");
	ImportUtilityManager.registerImportMode("npc", "MCDM", sLabel, ImportNPCManagerRWI.importFleeMortals);

	initImportStateOriginal = ImportNPCManager.initImportState;
	ImportNPCManager.initImportState = initImportState;

	importHelperSizeTypeAlignmentOriginal = ImportNPCManager.importHelperSizeTypeAlignment;
	ImportNPCManager.importHelperSizeTypeAlignment = importHelperSizeTypeAlignment;

	appendActionDescOriginal = ImportNPCManager.appendActionDesc;
	ImportNPCManager.appendActionDesc = appendActionDesc;
end

function importFleeMortals(sStats, sDesc)
	bIsFleeMortals = true;
	ImportNPCManager.import2022(sStats, sDesc)
	bIsFleeMortals = false;
end

function initImportState(sStatBlock, sDesc)
	local tImportState = initImportStateOriginal(sStatBlock, sDesc);
	tImportState.bIsFleeMortals = bIsFleeMortals;
	return tImportState;
end

-- Flee Mortals monsters can have more interesting subtypes
function importHelperSizeTypeAlignment(tImportState)
	if tImportState.bIsFleeMortals then
		-- Example: Huge Elemental (Earth, Water), Any Alignment
		ImportNPCManager.nextImportLine(tImportState);
		if (tImportState.sActiveLine or "") ~= "" then
			local sSize, sType, sAlignment = tImportState.sActiveLine:match("(%w+) ([^%(,]+ ?%(?[^%)]*%)?), (.+)");
			DB.setValue(tImportState.node, "size", "string", sSize);
			DB.setValue(tImportState.node, "type", "string", sType);
			DB.setValue(tImportState.node, "alignment", "string", sAlignment);

			ImportNPCManager.addStatOutput(tImportState, string.format("<p><b><i>%s</i></b></p>", tImportState.sActiveLine));
		end
	else
		importHelperSizeTypeAlignmentOriginal(tImportState);
	end
end

-- CR, Role, and XP all come out last in the PDF.
function appendActionDesc(tImportState, s)
	local sChallenge, sRole, sXp;
	if tImportState.bIsFleeMortals then
		sChallenge, sRole = tImportState.sActiveLine:match("^CR ([%d\\]+) (%w+)$");
		sXp = tImportState.sActiveLine:match("^([%d,]+) XP$");
	end
	if sChallenge then
		ImportNPCManager.finalizeAction(tImportState);
		table.insert(tImportState.tStatOutput, 2, string.format("<b>%s</b>", tImportState.sActiveLine));
		DB.setValue(tImportState.node, "cr", "string", sChallenge);
		DB.setValue(tImportState.node, "role", "string", sRole);
	elseif sXp then
		tImportState.tStatOutput[2] = string.format("<p>%s %s</p>", tImportState.tStatOutput[2], tImportState.sActiveLine);
		sXp = sXp:gsub(",","");
		DB.setValue(tImportState.node, "xp", "number", tonumber(sXp));
	else
		appendActionDescOriginal(tImportState, s);
	end
end

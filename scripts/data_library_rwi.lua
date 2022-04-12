-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	local rNPCRecordInfo = LibraryData.getRecordTypeInfo("npc");
	rNPCRecordInfo.aCustomFilters["Role"] = {sField = "role"};
end
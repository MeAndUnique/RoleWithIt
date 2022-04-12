-- 
-- Please see the license file included with this distribution for 
-- attribution and copyright information.
--

function onInit()
	if super and super.onInit then
		super.onInit();
	end

	onSummaryChanged();
	update();
end

function onSummaryChanged()
	super.onSummaryChanged();

	local sRole = role.getValue();
	if sRole ~= "" then
		local sText = summary_label.getValue();
		if sText ~= "" then
			sText = sText .. ", " .. sRole;
		else
			sText = sRole;
		end
		summary_label.setValue(sText);
	end
end

function update()
	super.update()
	local nodeRecord = getDatabaseNode();
	local bReadOnly = WindowManager.getReadOnlyState(nodeRecord);
	updateControl("role", bReadOnly, bReadOnly);
end
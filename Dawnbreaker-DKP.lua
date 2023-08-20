DawnbreakerDKP = LibStub("AceAddon-3.0"):NewAddon("DawnbreakerDKP", "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceTimer-3.0")
DawnbreakerDKP.var =  {
	--Main Window Variables
	mainFrame = nil,
	itemSelector = nil,
	initBox = nil,
	currentItems = {[0] = "<Manual Bid>"},
	selectedItem = nil,
	bidMinMS = 10,
	bidMinOS = 1,
	bidTimer = 30,
	initText = "",
	playerData = {},
	--numWhispers = 0,
	whisperList = {[0] = "<No Bids>"},
	currentWhisperWinner = nil,
	
	--Bid Window Variables
	bidWindow = nil,
	classBidWindow = nil,
	bidTimerWidget = nil,
	bidTickWidget = nil,
	
	bidsLabel = nil,
	currentBids = {},
	bidCount = 0,
	currentClassBids = {},
	
	bidWinnerBox = nil,
	bidActualAmtBox = nil,
	bidActualWinner = "",
	bidActualAmt = 0,

	bidConfirmBox = nil,
	bidConfirmBtn = nil,
	bidConfirmed = false,
	bidOpen = false,
	classBidOpen = false,
	
	bidTimeRemaining = 0,
	
	testVar=nil
}

AceGUI = LibStub("AceGUI-3.0")

local function Log(msg)
	DEFAULT_CHAT_FRAME:AddMessage("[Dawnbreaker DKP] " .. msg, 0.8, 0.8, 0.1)
end

local function SendRaidWarningMessage(msg)
	SendChatMessage(msg, "RAID_WARNING", nil, nil)
end

local function SendRaidMessage(msg)
	SendChatMessage(msg, "RAID", nil, nil)
end

local function SendWhisper(player, msg)

	if player == UnitName("player") then
		Log(msg)
		return
	end

	SendChatMessage("[Dawnbreaker DKP] " .. msg, "WHISPER", nil, player)
	--Log(player .. ": " .. msg)
end

function DawnbreakerDKP:OnInitialize()
    DawnbreakerDKP:RegisterEvent("CHAT_MSG_WHISPER", "OnWhisper")
	DawnbreakerDKP:RegisterEvent("LOOT_OPENED", "OnLootOpened")
    DawnbreakerDKP.CreateGUI()
end

local function CancelBids(player)
	for k,v in pairs(DawnbreakerDKP.var.currentBids) do
		if v.name == player then
			DawnbreakerDKP.var.currentBids[k] = nil
			DawnbreakerDKP.var.bidCount = DawnbreakerDKP.var.bidCount-1
		end
	end
end

local function CancelClassBids(player)
	for k,v in pairs(DawnbreakerDKP.var.currentClassBids) do
		if v.name == player then
			DawnbreakerDKP.var.currentClassBids[k] = nil
		end
	end
end

local function SortCurrentBids()
	local t = {}
    for k, v in pairs(DawnbreakerDKP.var.currentBids) do
        table.insert(t, v)
    end

    table.sort(t, function(a, b)
        if a.type:lower() == "ms" and b.type:lower() == "os" then
            return true
		elseif a.type:lower() == "os" and b.type:lower() == "ms" then
			return false
		elseif a.bid > b.bid then
			return true
        else
			return false
		end
    end)
	
	DawnbreakerDKP.var.currentBids = t
end

local function StringifyCurrentBids()
	local str = ""
	for k,v in pairs(DawnbreakerDKP.var.currentBids) do
		str = str .. v.type .. " " .. v.bid .. " : " .. v.name .. " " .. v.review .. "\r\n"
	end
	return str
end

local function StringifyCurrentClassBids()
	local str = ""
	for k,v in pairs(DawnbreakerDKP.var.currentClassBids) do
		str = str .. v.name .. "\r\n"
	end
	return str
end


local function HandleBid(self, message, player, guildRank)
	message = message:lower()
    local _, _, bidType, bidArgument = string.find(message, "(%w+) (%w+)")
	
	if bidType == nil then
		SendWhisper(player, "Bid rejected: unrecognized format.")
		return
	end
	
	bidType = bidType:lower()
	if bidType == "cancel" then
		CancelBids(player)
		SortCurrentBids()
		local bidsText = StringifyCurrentBids()
		DawnbreakerDKP.var.bidsLabel:SetText(bidsText)
		SendWhisper(player, "Your bid has been canceled.")
		return
	elseif bidType ~= "ms" and bidType ~= "os" then
		SendWhisper(player, "Bid rejected: unrecognized format. Bid must start with \"ms\", \"os\", or \"cancel bid\".")
		return
	end
	
	bidArgument = bidArgument:lower()
	if bidArgument ~= "min" and bidArgument ~= "max" and tonumber(bidArgument) == nil then
		SendWhisper(player, "Bid rejected: unrecognized format. Bid amount must be a valid bid number, or \"min\" / \"max\".")
		return
	end
	
	local playerDKP = tonumber(DawnbreakerDKP.var.playerData[player])
	reviewStr = ""
	if playerDKP == nil then
		if bidArgument == "max" then
			SendWhisper(player, "Bid rejected: Your DKP is not currently being tracked within the addon. Please use an explicit number for your bid.")
			return
		else		
			playerDKP = 200
			reviewStr = "(*)"
		end
	end

	local bidAmount = 0
	if bidType == "ms" then
		if guildRank=="Trial" then
			reviewStr = "(TRIAL)"
		end
		-- MS MAX
		if bidArgument == "min" then
			if DawnbreakerDKP.var.bidMinMS > playerDKP then
				SendWhisper(player, "Your DKP Balance is <" .. DawnbreakerDKP.var.bidMinMS .. ". You will be charged " .. DawnbreakerDKP.var.bidMinMS .. " if no other players bid.")
				-- Need to change Bid Amount in Bidlist Window
				bidAmount = playerDKP
			else
				bidAmount = DawnbreakerDKP.var.bidMinMS
			end
		-- MS MIN
		elseif bidArgument == "max" then
			if DawnbreakerDKP.var.bidMinMS > playerDKP then
				SendWhisper(player, "Your DKP Balance is <" .. DawnbreakerDKP.var.bidMinMS .. ". You will be charged " .. DawnbreakerDKP.var.bidMinMS .. " if no other players bid.")
				end
			bidAmount = playerDKP
		-- Bid amount lower than MS MIN
		elseif tonumber(bidArgument) < DawnbreakerDKP.var.bidMinMS then
			SendWhisper(player, "Bid rejected; the minimum main spec bid is " .. DawnbreakerDKP.var.bidMinMS .. ".")
			return
		elseif playerDKP < tonumber(DawnbreakerDKP.var.bidMinMS) then
			bidAmount = playerDKP
			SendWhisper(player, "Your DKP Balance is " .. playerDKP .. ", which is <" .. DawnbreakerDKP.var.bidMinMS .. ". Your bid for " .. DawnbreakerDKP.var.bidMinMS .. " has been Accepted. You will be charged " .. DawnbreakerDKP.var.bidMinMS .. " you are the highest bidder with the highest DKP balance.")
		elseif tonumber(bidArgument) > playerDKP then
			SendWhisper(player, "Bid rejected; your current DKP total is " .. playerDKP .. ".")
			return
		-- Accepted MS bid
		else
			bidAmount = tonumber(bidArgument)
		end	
	elseif bidType == "os" then
		-- OS MIN
		if bidArgument == "min" then
			if DawnbreakerDKP.var.bidMinOS > playerDKP then
				SendWhisper(player, "Your DKP Balance is <" .. DawnbreakerDKP.var.bidMinOS .. ". You will be charged " .. DawnbreakerDKP.var.bidMinOS .. " if no other players bid.")
				bidAmount = playerDKP
			else bidAmount = DawnbreakerDKP.var.bidMinOS
			end
		-- OS MAX
		elseif bidArgument == "max" then
			if DawnbreakerDKP.var.bidMinOS > playerDKP then
				SendWhisper(player, "Your DKP Balance is <" .. DawnbreakerDKP.var.bidMinOS .. ". You will be charged " .. DawnbreakerDKP.var.bidMinOS .. " if no other players bid.")
				end
			bidAmount = playerDKP
		-- Bid Amt less than OS Min
		elseif tonumber(bidArgument) < DawnbreakerDKP.var.bidMinOS then
			SendWhisper(player, "Bid rejected; the minimum off-spec bid is " .. DawnbreakerDKP.var.bidMinOS .. ".")
			return
		-- Player DKP lower than OS MIN
		elseif playerDKP < tonumber(DawnbreakerDKP.var.bidMinOS) then
			bidAmount = playerDKP
			SendWhisper(player, "Your DKP Balance is " .. playerDKP .. ", which is <" .. DawnbreakerDKP.var.bidMinOS .. ". Your bid for " .. DawnbreakerDKP.var.bidMinOS .. " has been Accepted. You will be charged " .. DawnbreakerDKP.var.bidMinOS .. " you are the highest bidder with the highest DKP balance.")
		-- Bid higher than Player DKP
		elseif tonumber(bidArgument) > playerDKP then
			SendWhisper(player, "Bid rejected; your current DKP total is " .. playerDKP .. ".")
			return
		-- Accepted OS bid
		else
			bidAmount = tonumber(bidArgument)
		end
	end
	
	CancelBids(player)
	table.insert(DawnbreakerDKP.var.currentBids, {type=bidType, bid=bidAmount, name=player, review=reviewStr})
	
	--Drop down for bidders
	if(DawnbreakerDKP.var.whisperList[0] == "<No Bids>") then 
		DawnbreakerDKP.var.whisperList[0] = player 
		DawnbreakerDKP.var.bidWinnerDropDown:SetList(DawnbreakerDKP.var.whisperList)
		DawnbreakerDKP.var.bidWinnerDropDown:SetValue(nil)
	else 
		-- if already in list do nothing
		local playerInList = false
		for p=0,#DawnbreakerDKP.var.whisperList do
		 	if DawnbreakerDKP.var.whisperList[p] == player then
		 		playerInList = true
		 		break
			end
		end
		
		if playerInList == false then
			DawnbreakerDKP.var.whisperList[#DawnbreakerDKP.var.whisperList+1]=player
			DawnbreakerDKP.var.bidWinnerDropDown:SetList(DawnbreakerDKP.var.whisperList)
			DawnbreakerDKP.var.bidWinnerDropDown:SetValue(nil)
		end
	
	end
	DawnbreakerDKP.var.bidWinnerDropDown:SetList(DawnbreakerDKP.var.whisperList)
	DawnbreakerDKP.var.bidWinnerDropDown:SetValue(nil)
	
	DawnbreakerDKP.var.bidCount = DawnbreakerDKP.var.bidCount+1
	if reviewStr ~= "" then
		Log("WARNING: DKP data for " .. player .. " is not currently being tracked. Updates to the website will still work, but you will have to manually verify their DKP to prevent overspending.")
	end
	SendWhisper(player, bidType:upper() .. " bid for " .. bidAmount .. " has been accepted.")
	
	SortCurrentBids()
	local bidsText = StringifyCurrentBids()
	DawnbreakerDKP.var.bidsLabel:SetText(bidsText)
end

local function HandleClassBid(self, message, player)
	message = message:lower()
    local _, _, bidArgument = string.find(message, "(%w+)")
	
	if bidArgument ~= "need" then
		return
	end
	
	CancelClassBids(player)
	table.insert(DawnbreakerDKP.var.currentClassBids, {name=player})
	SendWhisper(player, "Suicide Kings bid for 10 DKP has been accepted.")
	
	local bidsText = StringifyCurrentClassBids()
	DawnbreakerDKP.var.bidsLabel:SetText(bidsText)
end

function DawnbreakerDKP:OnWhisper(self, message, player, ...)
	
	player = string.match(player, "(.*)%-.*")
	local guildName, guildRankName, guildRankIndex = GetGuildInfo(player)

	if message:lower() == "?dkp" then
		local dkp = DawnbreakerDKP.var.playerData[player]
		
		if next(DawnbreakerDKP.var.playerData)==nil then
			print("================DKP Data Empty================")
			SendWhisper(player, "DKP data is not currently loaded. Check the website.")
		elseif dkp == nil then
			print("================This Player is not being tracked.================")
			SendWhisper(player,"Character DKP not being tracked, but the DKP Data is loaded.")
		else
			SendWhisper(player, "You have " .. dkp .. " dkp.")
		end
	end
	
	if DawnbreakerDKP.var.bidOpen then
		HandleBid(self, message, player, guildRankName)

	elseif DawnbreakerDKP.var.classBidOpen then
		HandleClassBid(self, message, player)
	end
end

local function PopulateLootList()
	local numItems = GetNumLootItems()
	if numItems == 0 then
		return
	end
	
	DawnbreakerDKP.var.currentItems = table.wipe(DawnbreakerDKP.var.currentItems)
	DawnbreakerDKP.var.selectedItem = nil
	for i=1,numItems do
		local lootLink = GetLootSlotLink(i);
		if lootLink ~= nil then
			DawnbreakerDKP.var.currentItems[i] = lootLink
		end
	end
	DawnbreakerDKP.var.currentItems[#DawnbreakerDKP.var.currentItems+1]="<Manual Bid>"
	DawnbreakerDKP.var.itemSelector:SetList(DawnbreakerDKP.var.currentItems)
	DawnbreakerDKP.var.itemSelector:SetValue(nil)
end

function DawnbreakerDKP:OnLootOpened(...)
	pcall(PopulateLootList)
end

local function ConfirmBid(selectedItem)
	DawnbreakerDKP.var.bidConfirmed = true
	DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(true)
	
	local _, _, itemId = string.find(selectedItem, "item:(%\d*):")
	if itemId == nil then
		itemId = "-1"
	end
	
	local _, _, itemName = string.find(selectedItem, "%[(.*)%]")
	if itemName == nil then
		itemName = "Manual Entry"
	end
	
	local data = "beginDKPEntry:" .. DawnbreakerDKP.var.bidWinnerBox:GetText() .. ";" .. itemId .. ";" .. itemName .. ";-" .. DawnbreakerDKP.var.bidActualAmtBox:GetText() .. ":endDKPEntry"
	DawnbreakerDKP.var.bidConfirmBox:SetText(data)
	
	if DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidWinnerBox:GetText()] ~= nil then
		DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] = DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] - DawnbreakerDKP.var.bidActualAmtBox:GetText()
		SendWhisper(DawnbreakerDKP.var.bidActualWinner, "You now have " .. DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] .. " dkp.")
	end
	
	SendRaidWarningMessage("Congrats to " .. DawnbreakerDKP.var.bidWinnerBox:GetText() .. " on winning " .. selectedItem .. " for " .. DawnbreakerDKP.var.bidActualAmtBox:GetText() .. " dkp!")

	Log("Bid has been confirmed. Make sure to copy the confirmation data to the website or it will not be tracked.")
	
	--Reset the Bid Winner Drop Down 
	DawnbreakerDKP.var.whisperList = {[0] = "<No Bids>"}
	DawnbreakerDKP.var.bidWinnerDropDown:SetList(DawnbreakerDKP.var.whisperList)
	DawnbreakerDKP.var.bidWinnerDropDown:SetValue(nil)
	
end

local function ConfirmClassBid(selectedItem)
	DawnbreakerDKP.var.bidConfirmed = true
	DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(true)
	
	local _, _, itemId = string.find(selectedItem, "item:(%\d*):")
	if itemId == nil then
		itemId = "-1"
	end
	
	local _, _, itemName = string.find(selectedItem, "%[(.*)%]")
	if itemName == nil then
		itemName = "Manual Entry"
	end
	
	local data = "beginSKEntry:" .. DawnbreakerDKP.var.bidActualWinner .. ";" .. itemId .. ";" .. itemName .. ";-" .. DawnbreakerDKP.var.bidActualAmt .. ":endSKEntry"
	DawnbreakerDKP.var.bidConfirmBox:SetText(data)
	
	if DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] ~= nil then
		DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] = DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] - DawnbreakerDKP.var.bidActualAmt
		SendWhisper(DawnbreakerDKP.var.bidActualWinner, "You now have " .. DawnbreakerDKP.var.playerData[DawnbreakerDKP.var.bidActualWinner] .. " dkp.")
	end
	
	SendRaidWarningMessage("Congrats to " .. DawnbreakerDKP.var.bidActualWinner .. " on winning " .. selectedItem .. " for " .. DawnbreakerDKP.var.bidActualAmt .. " dkp!")

	Log("Bid has been confirmed. Make sure to copy the confirmation data to the website or it will not be tracked.")
end

local function PrintCurrentBids()
	for index, data in ipairs(DawnbreakerDKP.var.currentBids) do
		local printBid = ""
    	for key, value in pairs(data) do
			if key == "name" then
				printBid = value .. printBid
			elseif key == "bid" then
				printBid = printBid .. ":" .. value
			elseif key == "type" then
				printBid = printBid .. " " .. value
			end
		end
		print (printBid)
	end
end

local function DrawBidWindow(selectedItem, bidMinMS, bidMinOS, bidTimer)
	DawnbreakerDKP.var.bidWindow = AceGUI:Create("Frame")
    DawnbreakerDKP.var.bidWindow:SetTitle(selectedItem)
	DawnbreakerDKP.var.bidWindow:SetStatusText("Time Remaining: " .. bidTimer .. "s")
    DawnbreakerDKP.var.bidWindow:SetWidth(335)
    DawnbreakerDKP.var.bidWindow:SetHeight(380)
    DawnbreakerDKP.var.bidWindow:SetPoint("CENTER", "UIParent", "CENTER", 215, -12);
	DawnbreakerDKP.var.bidWindow:SetCallback("OnClose", function(widget)
		if not DawnbreakerDKP.var.bidConfirmed then
			-- if No bidders then print "There were no bids."
			if DawnbreakerDKP.var.bidCount == 0 then -- next(DawnbreakerDKP.var.currentBids ~= nil) 
				SendRaidMessage("There were no bids.") 
			end
			SendRaidMessage("Bid on " .. selectedItem .. " has been canceled.")
		end
		if DawnbreakerDKP.var.bidTimerWidget ~= nil then
			DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.bidTimerWidget)
			DawnbreakerDKP.var.BidTimerWidget = nil
		end
		if DawnbreakerDKP.var.bidTickWidget ~= nil then
			DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.bidTickWidget)
			DawnbreakerDKP.var.BidTickWidget = nil
		end
		DawnbreakerDKP.var.bidWindow = nil
		DawnbreakerDKP.var.bidOpen = false
		DawnbreakerDKP.var.whisperList = {[0]="<No Bids>"}
		AceGUI:Release(widget)
	end)
	
	local bidsGroup = AceGUI:Create("InlineGroup")
	bidsGroup:SetTitle("Current Bids")
	bidsGroup:SetLayout("Fill")
	DawnbreakerDKP.var.bidWindow:AddChild(bidsGroup)
	
	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("Flow")
	bidsGroup:AddChild(scrollFrame)
	
	DawnbreakerDKP.var.bidsLabel = AceGUI:Create("Label")
	DawnbreakerDKP.var.bidsLabel:SetText("")
	scrollFrame:AddChild(DawnbreakerDKP.var.bidsLabel)
	
	DawnbreakerDKP.var.bidWinnerBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidWinnerBox:SetLabel("Bid Winner:")
	DawnbreakerDKP.var.bidWinnerBox:SetText("")
	DawnbreakerDKP.var.bidWinnerBox:SetMaxLetters(0)
	DawnbreakerDKP.var.bidWinnerBox:SetCallback("OnEnterPressed", function(widget, name, value) 
        DawnbreakerDKP.var.bidActualWinner = value
		DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(value == nil or value == "" or DawnbreakerDKP.var.bidActualAmt == nil or DawnbreakerDKP.var.bidActualAmt == "")
    end)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.bidWinnerBox)
	
	--create bidder name selector dropdown here
	DawnbreakerDKP.var.bidWinnerDropDown = AceGUI:Create("Dropdown")
	DawnbreakerDKP.var.bidWinnerDropDown:SetLabel("Select Winning Player")
	DawnbreakerDKP.var.bidWinnerDropDown:SetList(DawnbreakerDKP.var.whisperList)
	DawnbreakerDKP.var.bidWinnerDropDown:SetCallback("OnValueChanged", function(widget, name, key, ...)
		if (DawnbreakerDKP.var.whisperList[key] ~= "<No Bids>") then 
			DawnbreakerDKP.var.bidWinnerBox:SetText(DawnbreakerDKP.var.whisperList[key])
			DawnbreakerDKP.var.bidActualWinner = DawnbreakerDKP.var.whisperList[key]
			DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(false)
		end
	end)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.bidWinnerDropDown)		
	
	DawnbreakerDKP.var.bidActualAmtBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidActualAmtBox:SetLabel("Bid Amount:")
	DawnbreakerDKP.var.bidActualAmtBox:SetText("")
	DawnbreakerDKP.var.bidActualAmtBox:SetMaxLetters(0)
	DawnbreakerDKP.var.bidActualAmtBox:SetCallback("OnEnterPressed", function(widget, name, value) 
        DawnbreakerDKP.var.bidActualAmt = value
		DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(DawnbreakerDKP.var.bidActualWinner == nil or DawnbreakerDKP.var.bidActualWinner == "" or value == nil or value == "")
    end)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.bidActualAmtBox)
	
	DawnbreakerDKP.var.bidConfirmBtn = AceGUI:Create("Button")
	DawnbreakerDKP.var.bidConfirmBtn:SetText("Confirm And Close Bid")
    DawnbreakerDKP.var.bidConfirmBtn:SetCallback("OnClick", function()
		ConfirmBid(selectedItem, bidMinMS, bidMinOS)
	end)
	DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(true)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.bidConfirmBtn)
	
	DawnbreakerDKP.var.printBidsBtn = AceGUI:Create("Button")
	DawnbreakerDKP.var.printBidsBtn:SetText("Print Bids")
    DawnbreakerDKP.var.printBidsBtn:SetCallback("OnClick", PrintCurrentBids)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.printBidsBtn)
	
	DawnbreakerDKP.var.bidConfirmBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidConfirmBox:SetLabel("Copy to website after confirmation:")
	DawnbreakerDKP.var.bidConfirmBox:SetText("")
	DawnbreakerDKP.var.bidConfirmBox:SetMaxLetters(0)
	DawnbreakerDKP.var.bidWindow:AddChild(DawnbreakerDKP.var.bidConfirmBox)
	
    DawnbreakerDKP.var.bidWindow:Show()
end

local function DrawClassBidWindow(selectedItem, bidTimer)
	DawnbreakerDKP.var.classBidWindow = AceGUI:Create("Frame")
    DawnbreakerDKP.var.classBidWindow:SetTitle(selectedItem)
	DawnbreakerDKP.var.classBidWindow:SetStatusText("Time Remaining: " .. bidTimer .. "s")
    DawnbreakerDKP.var.classBidWindow:SetWidth(335)
    DawnbreakerDKP.var.classBidWindow:SetHeight(350)
    DawnbreakerDKP.var.classBidWindow:SetPoint("CENTER", "UIParent", "CENTER", 215, -12);
	DawnbreakerDKP.var.classBidWindow:SetCallback("OnClose", function(widget)
		if not DawnbreakerDKP.var.bidConfirmed then
			SendRaidMessage("Bid on " .. selectedItem .. " has been canceled.")
		end
		if DawnbreakerDKP.var.bidTimerWidget ~= nil then
			DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.bidTimerWidget)
			DawnbreakerDKP.var.BidTimerWidget = nil
		end
		if DawnbreakerDKP.var.bidTickWidget ~= nil then
			DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.bidTickWidget)
			DawnbreakerDKP.var.BidTickWidget = nil
		end
		DawnbreakerDKP.var.classBidWindow = nil
		DawnbreakerDKP.var.classBidOpen = false
		AceGUI:Release(widget)
	end)
	
	local bidsGroup = AceGUI:Create("InlineGroup")
	bidsGroup:SetTitle("Current Bids")
	bidsGroup:SetLayout("Fill")
	DawnbreakerDKP.var.classBidWindow:AddChild(bidsGroup)
	
	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("Flow")
	bidsGroup:AddChild(scrollFrame)
	
	DawnbreakerDKP.var.bidsLabel = AceGUI:Create("Label")
	DawnbreakerDKP.var.bidsLabel:SetText("")
	scrollFrame:AddChild(DawnbreakerDKP.var.bidsLabel)
	
	DawnbreakerDKP.var.bidWinnerBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidWinnerBox:SetLabel("Bid Winner:")
	DawnbreakerDKP.var.bidWinnerBox:SetText("")
	DawnbreakerDKP.var.bidWinnerBox:SetMaxLetters(0)
	DawnbreakerDKP.var.bidWinnerBox:SetCallback("OnEnterPressed", function(widget, name, value) 
        DawnbreakerDKP.var.bidActualWinner = value
		DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(value == nil or value == "" or DawnbreakerDKP.var.bidActualAmt == nil or DawnbreakerDKP.var.bidActualAmt == "")
    end)
	DawnbreakerDKP.var.classBidWindow:AddChild(DawnbreakerDKP.var.bidWinnerBox)
	
	DawnbreakerDKP.var.bidActualAmtBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidActualAmtBox:SetLabel("Bid Amount:")
	DawnbreakerDKP.var.bidActualAmtBox:SetText("")
	DawnbreakerDKP.var.bidActualAmtBox:SetMaxLetters(0)
	DawnbreakerDKP.var.bidActualAmtBox:SetCallback("OnEnterPressed", function(widget, name, value) 
        DawnbreakerDKP.var.bidActualAmt = value
		DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(DawnbreakerDKP.var.bidActualWinner == nil or DawnbreakerDKP.var.bidActualWinner == "" or value == nil or value == "")
    end)
	DawnbreakerDKP.var.classBidWindow:AddChild(DawnbreakerDKP.var.bidActualAmtBox)
	
	DawnbreakerDKP.var.bidConfirmBtn = AceGUI:Create("Button")
	DawnbreakerDKP.var.bidConfirmBtn:SetText("Confirm And Close Bid")
    DawnbreakerDKP.var.bidConfirmBtn:SetCallback("OnClick", function()
		ConfirmClassBid(selectedItem)
	end)
	DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(true)
	DawnbreakerDKP.var.classBidWindow:AddChild(DawnbreakerDKP.var.bidConfirmBtn)
	
	DawnbreakerDKP.var.bidConfirmBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.bidConfirmBox:SetLabel("Copy to website after confirmation:")
	DawnbreakerDKP.var.bidConfirmBox:SetText("")
	DawnbreakerDKP.var.bidConfirmBox:SetMaxLetters(0)
	DawnbreakerDKP.var.classBidWindow:AddChild(DawnbreakerDKP.var.bidConfirmBox)
	
    DawnbreakerDKP.var.classBidWindow:Show()
end

local function SetBidWinnerFields(winner, bidAmt, bidType, bidMinMS, bidMinOS)
	DawnbreakerDKP.var.bidActualWinner = winner
	DawnbreakerDKP.var.bidActualAmt = bidAmt
	if bidType == "ms" and bidAmt < bidMinMS then bidAmt = bidMinMS
	elseif bidType == "os" and bidAmt < bidMinOS then bidAmt = bidMinOS
	end
	DawnbreakerDKP.var.bidWinnerBox:SetText(winner)
	DawnbreakerDKP.var.bidActualAmtBox:SetText(bidAmt)
	DawnbreakerDKP.var.bidConfirmBtn:SetDisabled(winner == nil or winner == "" or bidAmt == nil or bidAmt == "")
end

local function GetWinnerAndBidAmounts(bidMinMS, bidMinOS)
	local winner = DawnbreakerDKP.var.currentBids[1]
	if winner == nil then
		return nil, nil, nil
	end
	
	local runnerUp = DawnbreakerDKP.var.currentBids[2]
	if runnerUp == nil then
		if winner.type == "ms" then
			return winner.name, bidMinMS, winner.type
		else
			return winner.name, bidMinOS, winner.type
		end
	end
	
	if winner.type == "ms" and runnerUp.type == "os" then
		return winner.name, bidMinMS, winner.type
	end
	
	if winner.bid > runnerUp.bid then
		local negCheck = runnerUp.bid + 1
		-- Handle negative values
		if winner.type == "ms" and negCheck < bidMinMS then
			negcheck = bidMinMS 
		elseif winner.type == "os" and negCheck < bidMinOS then
			negCheck = bidMinOS
		end
					
		return winner.name, negCheck, winner.type
	else
		-- this happens when there is a Winner/RunnerUp Tie
		local tieNegCheck = winner.bid
		
		if winner.type == "ms" and tieNegCheck < bidMinMS then
			tieNegCheck = bidMinMS
		elseif winner.type == "os" and tieNegCheck < bidMinOS then
			tieNegCheck = bidMinOS
		end
		
		return "", tieNegCheck, winner.type
	end
end

function DawnbreakerDKP:OnTimeElapsed(bidMinMS, bidMinOS)
	DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.BidTimerWidget) 
	DawnbreakerDKP.var.BidTimerWidget = nil
	DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.BidTickWidget)
	DawnbreakerDKP.var.BidTickWidget = nil
	DawnbreakerDKP.var.bidOpen = false
	if next(DawnbreakerDKP.var.currentBids) ~= nil then
		local winner, bidAmt, bidType = GetWinnerAndBidAmounts(bidMinMS, bidMinOS)
		SetBidWinnerFields(winner, bidAmt, bidType, bidMinMS, bidMinOS)
	else SendRaidMessage("There were no bids.")
	end
	SendRaidWarningMessage("Bidding is closed!")
end

function DawnbreakerDKP:OnTimeElapsedClassBid()
	DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.BidTimerWidget)
	DawnbreakerDKP.var.BidTimerWidget = nil
	DawnbreakerDKP:CancelTimer(DawnbreakerDKP.var.BidTickWidget)
	DawnbreakerDKP.var.BidTickWidget = nil
	DawnbreakerDKP.var.classBidOpen = false
	DawnbreakerDKP.var.bidActualAmt = 10
	DawnbreakerDKP.var.bidActualAmtBox:SetText(10)
	SendRaidWarningMessage("Bidding is closed!")
end

function DawnbreakerDKP:OnBidTick(selectedItem)
	if DawnbreakerDKP.var.bidTimeRemaining > 10 and DawnbreakerDKP.var.bidTimeRemaining <= 10.1 then
		SendRaidWarningMessage("10 seconds remaining on " .. selectedItem .. " ")
	end
	
	if DawnbreakerDKP.var.bidTimeRemaining > 0.1 then
		DawnbreakerDKP.var.bidTimeRemaining = DawnbreakerDKP.var.bidTimeRemaining - 0.1
		DawnbreakerDKP.var.bidWindow:SetStatusText("Time Remaining: " .. DawnbreakerDKP.var.bidTimeRemaining .. "s")
	else
		DawnbreakerDKP.var.bidWindow:SetStatusText("Time is up!")
	end
end

function DawnbreakerDKP:OnBidTickClassBid()
	if DawnbreakerDKP.var.bidTimeRemaining > 10 and DawnbreakerDKP.var.bidTimeRemaining <= 10.1 then
		SendRaidWarningMessage("10 seconds remaining.")
	end
	
	if DawnbreakerDKP.var.bidTimeRemaining > 0.1 then
		DawnbreakerDKP.var.bidTimeRemaining = DawnbreakerDKP.var.bidTimeRemaining - 0.1
		DawnbreakerDKP.var.classBidWindow:SetStatusText("Time Remaining: " .. DawnbreakerDKP.var.bidTimeRemaining .. "s")
	else
		DawnbreakerDKP.var.classBidWindow:SetStatusText("Time is up!")
	end
end

local function OpenBid(selectedItem, bidMinMS, bidMinOS, bidTimer)
    DrawBidWindow(selectedItem, bidMinMS, bidMinOS, bidTimer)
	DawnbreakerDKP.var.bidTimeRemaining = bidTimer
	DawnbreakerDKP.var.bidTimerWidget = DawnbreakerDKP:ScheduleTimer("OnTimeElapsed", bidTimer, bidMinMS, bidMinOS)
	DawnbreakerDKP.var.bidTickWidget = DawnbreakerDKP:ScheduleRepeatingTimer("OnBidTick", 0.1, selectedItem)
	DawnbreakerDKP.var.currentBids = table.wipe(DawnbreakerDKP.var.currentBids)
	DawnbreakerDKP.var.bidCount = 0
	DawnbreakerDKP.var.bidActualWinner = "" 
	DawnbreakerDKP.var.bidActualAmt = ""
	DawnbreakerDKP.var.bidConfirmed = false
	DawnbreakerDKP.var.bidOpen = true
	SendRaidWarningMessage("Bidding is now open on " .. selectedItem .. "! Min MS bid: " .. bidMinMS .. "; Min OS bid: " .. bidMinOS)
	SendRaidWarningMessage("To bid on this item, whisper me with \"ms ##\", \"os ##\", or \"cancel bid\" to cancel. Examples: \"ms 30\", \"os min\", \"ms max\" (no quotes).")
end

local function TryOpenBid()
	local selectedItem = DawnbreakerDKP.var.selectedItem
	if selectedItem == nil then
		UIErrorsFrame:AddMessage("Error: Cannot open bid because no item has been selected.", 1, 0, 0)
		PlaySound(846)
		return
	end
	if DawnbreakerDKP.var.bidWindow ~= nil and DawnbreakerDKP.var.classBidWindow ~= nil then
		UIErrorsFrame:AddMessage("Error: A bid is already open.", 1, 0, 0)
		PlaySound(846)
		return
	end
	local bidMinMS = DawnbreakerDKP.var.bidMinMS
	local bidMinOS = DawnbreakerDKP.var.bidMinOS
	local bidTimer = DawnbreakerDKP.var.bidTimer
	OpenBid(selectedItem, bidMinMS, bidMinOS, bidTimer)
end

local function OpenClassBid(selectedItem, bidTimer)
	DrawClassBidWindow(selectedItem, bidTimer)
	DawnbreakerDKP.var.bidTimeRemaining = bidTimer
	DawnbreakerDKP.var.bidTimerWidget = DawnbreakerDKP:ScheduleTimer("OnTimeElapsedClassBid", bidTimer)
	DawnbreakerDKP.var.bidTickWidget = DawnbreakerDKP:ScheduleRepeatingTimer("OnBidTickClassBid", 0.1)
	DawnbreakerDKP.var.currentClassBids = table.wipe(DawnbreakerDKP.var.currentClassBids)
	DawnbreakerDKP.var.bidActualWinner = ""
	DawnbreakerDKP.var.bidActualAmt = ""
	DawnbreakerDKP.var.bidConfirmed = false
	DawnbreakerDKP.var.classBidOpen = true
	SendRaidWarningMessage("Suicide Kings bid is now open on " .. selectedItem .. "!")
	SendRaidWarningMessage("If you need this item, whisper me \"need\". The highest priority player on the corresponding class list to need will receive the item for 10 DKP.")
end

local function TryOpenClassBid()
	local selectedItem = DawnbreakerDKP.var.selectedItem
	if selectedItem == nil then
		UIErrorsFrame:AddMessage("Error: Cannot open bid because no item has been selected.", 1, 0, 0)
		PlaySound(846)
		return
	end
	if DawnbreakerDKP.var.bidWindow ~= nil and DawnbreakerDKP.var.classBidWindow ~= nil then
		UIErrorsFrame:AddMessage("Error: A bid is already open.", 1, 0, 0)
		PlaySound(846)
		return
	end
	local bidTimer = DawnbreakerDKP.var.bidTimer
	OpenClassBid(selectedItem, bidTimer)
end

local function CopyInitData()
    local initData = "beginSessionInit:"
	for i=1,40 do
		local playerName = GetRaidRosterInfo(i);
		if playerName ~= nil then
			initData = initData .. playerName .. ";"
		end
	end
	initData = initData .. ":endSessionInit"
	DawnbreakerDKP.var.initBox:SetText(initData)	
	Log("Session initialization data generated from current raid roster. Select and copy this text, then paste it to the website to start a new raid session.")
end

local function LoadData()
	loadstring("DawnbreakerDKP.var.playerData = " .. DawnbreakerDKP.var.initText)()
end

local function LoadWebsiteData()
    if pcall(LoadData) then
		Log("Website data loaded successfully.")
		-- for k,v in pairs(DawnbreakerDKP.var.playerData) do
			-- DEFAULT_CHAT_FRAME:AddMessage(k .. ": " .. v)
		-- end
		DawnbreakerDKP.var.pasteBox:SetText("")
	else
		Log("Error loading website data. Make sure you click \"Okay\" after pasting addon init data copied from the website.")
		UIErrorsFrame:AddMessage("Error: Failed to load website data.", 1, 0, 0)
		PlaySound(846)
	end
end

local function DumpWebsiteData()
	local t = {}
    for k, v in pairs(DawnbreakerDKP.var.playerData) do
        table.insert(t, k .. ": " .. v)
    end

    table.sort(t)
	for k,v in pairs(t) do
		print(v)
	end
end

local function DrawBidTab(container)
	DawnbreakerDKP.var.itemSelector = AceGUI:Create("Dropdown")
	DawnbreakerDKP.var.itemSelector:SetLabel("Select Item")
	DawnbreakerDKP.var.itemSelector:SetList(DawnbreakerDKP.var.currentItems)
	DawnbreakerDKP.var.itemSelector:SetCallback("OnValueChanged", function(widget, name, key, ...) 
        DawnbreakerDKP.var.selectedItem = DawnbreakerDKP.var.currentItems[key]
    end)
	container:AddChild(DawnbreakerDKP.var.itemSelector)
		
	local minBidMS_Slider = AceGUI:Create("Slider")
    minBidMS_Slider:SetLabel("Min Bid (MS)")
    minBidMS_Slider:SetSliderValues(1, 50, 1)
    minBidMS_Slider:SetValue(DawnbreakerDKP.var.bidMinMS)
    minBidMS_Slider:SetCallback("OnValueChanged", function(widget, name, value) 
        DawnbreakerDKP.var.bidMinMS = value 
    end)
	container:AddChild(minBidMS_Slider)
	
	local minBidOS_Slider = AceGUI:Create("Slider")
    minBidOS_Slider:SetLabel("Min Bid (OS)")
    minBidOS_Slider:SetSliderValues(1, 50, 1)
    minBidOS_Slider:SetValue(DawnbreakerDKP.var.bidMinOS)
    minBidOS_Slider:SetCallback("OnValueChanged", function(widget, name, value) 
        DawnbreakerDKP.var.bidMinOS = value
	end)
	container:AddChild(minBidOS_Slider)
	
	local timerSlider = AceGUI:Create("Slider")
    timerSlider:SetLabel("Bid Timer")
    timerSlider:SetSliderValues(5, 60, 5)
    timerSlider:SetValue(DawnbreakerDKP.var.bidTimer)
    timerSlider:SetCallback("OnValueChanged", function(widget, name, value) 
        DawnbreakerDKP.var.bidTimer = value
	end)
	container:AddChild(timerSlider)
	
    local openBidBtn = AceGUI:Create("Button")
	openBidBtn:SetText("Open DKP Bid")
    openBidBtn:SetCallback("OnClick", TryOpenBid)
	container:AddChild(openBidBtn)
	
	local dragBidItem = AceGUI:Create("ActionSlotItem")
	dragBidItem:SetLabel("Drag Item Here to Start Bid")
	dragBidItem:SetHeight(50)
	-- dragBidItem:SetWidth(25)
	dragBidItem:SetCallback("OnEnterPressed", function(widget, name, item)
		-- SendChatMessage(item, "say")
		local iName, iLink = GetItemInfo(item)
		DawnbreakerDKP.var.selectedItem = iLink
		TryOpenBid()
	end)
	container:AddChild(dragBidItem)
	
	-- local openClassBidBtn = AceGUI:Create("Button")
	-- openClassBidBtn:SetText("Open Class Bid")
    -- openClassBidBtn:SetCallback("OnClick", TryOpenClassBid)
	-- container:AddChild(openClassBidBtn)
end

local function DrawSetupTab(container)
	DawnbreakerDKP.var.initBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.initBox:SetLabel("Copy filled data below to website:")
	DawnbreakerDKP.var.initBox:SetText("")
	DawnbreakerDKP.var.initBox:SetMaxLetters(0)
	container:AddChild(DawnbreakerDKP.var.initBox)

    local sessionInitBtn = AceGUI:Create("Button")
	sessionInitBtn:SetText("Generate Session Init Data")
    sessionInitBtn:SetCallback("OnClick", CopyInitData)
	container:AddChild(sessionInitBtn)
	
	DawnbreakerDKP.var.pasteBox = AceGUI:Create("EditBox")
	DawnbreakerDKP.var.pasteBox:SetLabel("Paste Website Init Data Here:")
	DawnbreakerDKP.var.pasteBox:SetText("")
	DawnbreakerDKP.var.pasteBox:SetMaxLetters(0)
    DawnbreakerDKP.var.pasteBox:SetCallback("OnEnterPressed", function(widget, name, value) 
        DawnbreakerDKP.var.initText = value
    end)
	container:AddChild(DawnbreakerDKP.var.pasteBox)
	
	local websiteLoadBtn = AceGUI:Create("Button")
	websiteLoadBtn:SetText("Load Website Data")
    websiteLoadBtn:SetCallback("OnClick", LoadWebsiteData)
	container:AddChild(websiteLoadBtn)
	
	local dumpDataBtn = AceGUI:Create("Button")
	dumpDataBtn:SetText("View Current DKP Data")
    dumpDataBtn:SetCallback("OnClick", DumpWebsiteData)
	container:AddChild(dumpDataBtn)
end

-- Callback function for OnGroupSelected
local function SelectGroup(container, event, group)
	container:ReleaseChildren()
	if group == "tab1" then
		DrawBidTab(container)
	elseif group == "tab2" then
		DrawSetupTab(container)
	end
end

function DawnbreakerDKP:CreateGUI()
    DawnbreakerDKP.var.mainFrame = AceGUI:Create("Frame")
    DawnbreakerDKP.var.mainFrame:SetTitle("Dawnbreaker DKP")
    DawnbreakerDKP.var.mainFrame:SetWidth(245)
    DawnbreakerDKP.var.mainFrame:SetHeight(365)
    DawnbreakerDKP.var.mainFrame:SetPoint("CENTER", "UIParent", "CENTER", 500, 0);
	DawnbreakerDKP.var.mainFrame:SetLayout("Fill")
    DawnbreakerDKP.var.mainFrame:Hide()
	
	local tabGroup = AceGUI:Create("TabGroup")
	tabGroup:SetLayout("Flow")
	tabGroup:SetTabs({{text="Bids", value="tab1"}, {text="Setup", value="tab2"}})
	tabGroup:SetCallback("OnGroupSelected", SelectGroup)
	tabGroup:SelectTab("tab1")
	DawnbreakerDKP.var.mainFrame:AddChild(tabGroup)
end

SLASH_DDKP1 = "/ddkp"
SlashCmdList["DDKP"] = function(msg)
	DawnbreakerDKP.var.mainFrame:Show()
end
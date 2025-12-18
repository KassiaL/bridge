local M = {}
---@diagnostic disable-next-line: undefined-global
local appodeal = appodeal

local is_inited = false
local is_test_ads = false

local reward_callback = nil
local error_callback = nil
local close_callback = nil
local opened_callback = nil

function M.set_test_ads(test_ads)
	is_test_ads = test_ads
	if is_inited then
		error("Appodeal is already initialized. Can't change test ads mode.")
	end
end

local function user_consent_update(use_personal_ads)
	if appodeal then
		appodeal.set_user_consent(use_personal_ads) -- GDPR нужно сюда поместить данные
	end
end

local function set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
	reward_callback = _reward_callback
	close_callback = _close_callback
	error_callback = _error_callback
	opened_callback = _opened_callback
end

local function listener(self, message_id, message)
	if message_id == appodeal.MSG_ADS_INITED then
		is_inited = true
	elseif message_id == appodeal.MSG_REWARDED then
		if message.event == appodeal.EVENT_LOADED then

		elseif message.event == appodeal.EVENT_SHOWN then
			if opened_callback then opened_callback() end
		elseif message.event == appodeal.EVENT_REWARDED then
			if reward_callback then reward_callback() end
		elseif message.event == appodeal.EVENT_ERROR_LOAD then
			-- попробовать потом еще раз
			-- timer.delay(60, false, ads.create_rewarded_ad)
		elseif message.event == appodeal.EVENT_CLOSED then
			if close_callback then close_callback() end
		elseif message.event == appodeal.EVENT_ERROR_SHOW then
			if error_callback then error_callback() end
		end
	elseif message_id == appodeal.MSG_INTERSTITIAL then
		if message.event == appodeal.EVENT_SHOWN then
			if opened_callback then opened_callback() end
		elseif message.event == appodeal.EVENT_CLOSED then
			if close_callback then close_callback() end
		elseif message.event == appodeal.EVENT_ERROR_SHOW then
			if error_callback then error_callback() end
		end
	end
end

local function is_reward_ads_available()
	if appodeal and appodeal.is_rewarded_loaded() then
		return true
	else
		return false
	end
end

local function is_interstitial_ads_available()
	if appodeal and appodeal.is_interstitial_loaded() then
		return true
	else
		return false
	end
end

local function show_reward_ads(reward_callback, close_callback, error_callback, opened_callback)
	set_up_callbacks(reward_callback, close_callback, error_callback, opened_callback)
	local placementName = "default"
	if appodeal and appodeal.is_rewarded_loaded() then
		appodeal.show_rewarded(placementName)
	else
		if error_callback then
			error_callback()
		end
	end
end

local function show_interstitial_ads(close_callback, error_callback, opened_callback)
	set_up_callbacks(nil, close_callback, error_callback, opened_callback)
	local placementName = "default"
	if appodeal and appodeal.is_interstitial_loaded() then
		appodeal.show_interstitial(placementName)
	else
		if error_callback then
			error_callback()
		end
	end
end

function M.init_sdk()
	local application_key = sys.get_config_string("appodeal.appodeal_id", nil)
	if not application_key then
		error("appodeal.appodeal_id not found in config")
	end

	if appodeal then
		-- appodeal.set_user_consent(false)     -- GDPR нужно сюда поместить данные согласия пользователя
		appodeal.set_callback(listener)
		appodeal.initialize(application_key, is_test_ads)
	end
end

function M.is_sdk_inited()
	return is_inited
end

local ad_wrapper = require("bridge.ads_utils.ad_wrapper")

---@type ads
local ads = {
	is_reward_ads_available = is_reward_ads_available,
	is_interstitial_ads_available = function()
		return ad_wrapper.is_interstitial_ads_available(is_interstitial_ads_available)
	end,
	show_reward_ads = function(_reward_callback, _close_callback, _error_callback, _opened_callback)
		ad_wrapper.show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback, show_reward_ads)
	end,
	show_interstitial_ads = function(_close_callback, _error_callback, _opened_callback)
		ad_wrapper.show_interstitial_ads(_close_callback, _error_callback, _opened_callback, show_interstitial_ads)
	end,
	is_reward_ads_supported = function()
		return true
	end
}

M.ads = ads

return M

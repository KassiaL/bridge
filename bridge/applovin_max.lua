local M = {}
---@diagnostic disable-next-line: undefined-global
local applovin = applovin

local is_inited = false
local is_test_ads = false

local sdk_key = nil
local rewarded_ad_unit_id = nil
local interstitial_ad_unit_id = nil
local banner_ad_unit_id = nil

local reward_callback = nil
local error_callback = nil
local close_callback = nil
local opened_callback = nil

local rewarded_loaded = false
local interstitial_loaded = false
local banner_state = "hidden"
local banner_loaded = false
local banner_created = false
local banner_position = nil
local banner_showed = false
local banner_should_show = false

local RETRY_DELAY_SECONDS = 5

function M.set_config(params)
	assert(type(params) == "table", "AppLovin config must be a table")
	if is_inited then
		error("AppLovin is already initialized. Can't change config.")
	end

	if params.test_ads ~= nil then
		is_test_ads = params.test_ads
	end
	if params.sdk_key ~= nil then
		sdk_key = params.sdk_key
	end
	if params.rewarded_ad_unit_id ~= nil then
		rewarded_ad_unit_id = params.rewarded_ad_unit_id
	end
	if params.interstitial_ad_unit_id ~= nil then
		interstitial_ad_unit_id = params.interstitial_ad_unit_id
	end
	if params.banner_ad_unit_id ~= nil then
		banner_ad_unit_id = params.banner_ad_unit_id
	end
end

local function set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
	reward_callback = _reward_callback
	close_callback = _close_callback
	error_callback = _error_callback
	opened_callback = _opened_callback
end

local function load_rewarded()
	local ad_unit_id = rewarded_ad_unit_id
	if not ad_unit_id or ad_unit_id == "" then
		return
	end
	rewarded_loaded = false
	applovin.load_rewarded_ad(ad_unit_id)
end

local function load_interstitial()
	local ad_unit_id = interstitial_ad_unit_id
	if not ad_unit_id or ad_unit_id == "" then
		return
	end
	interstitial_loaded = false
	applovin.load_interstitial(ad_unit_id)
end

local function schedule_retry(fn)
	timer.delay(RETRY_DELAY_SECONDS, false, fn)
end

local function is_ad_unit_match(params, ad_unit_id)
	if not params or not ad_unit_id or ad_unit_id == "" then
		return false
	end
	return params.adUnitIdentifier == ad_unit_id
end

local function listener(self, name, params)
	if name == "OnSdkInitializedEvent" then
		return
	end

	if name == "OnRewardedAdLoadedEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			rewarded_loaded = true
		end
	elseif name == "OnRewardedAdLoadFailedEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			rewarded_loaded = false
			schedule_retry(load_rewarded)
		end
	elseif name == "OnRewardedAdDisplayedEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			rewarded_loaded = false
			if opened_callback then opened_callback() end
		end
	elseif name == "OnRewardedAdDisplayFailedEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			rewarded_loaded = false
			if error_callback then error_callback() end
			load_rewarded()
		end
	elseif name == "OnRewardedAdHiddenEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			if close_callback then close_callback() end
			load_rewarded()
		end
	elseif name == "OnRewardedAdReceivedRewardEvent" then
		if is_ad_unit_match(params, rewarded_ad_unit_id) then
			if reward_callback then reward_callback() end
		end
	elseif name == "OnInterstitialAdLoadedEvent" then
		if is_ad_unit_match(params, interstitial_ad_unit_id) then
			interstitial_loaded = true
		end
	elseif name == "OnInterstitialAdLoadFailedEvent" then
		if is_ad_unit_match(params, interstitial_ad_unit_id) then
			interstitial_loaded = false
			schedule_retry(load_interstitial)
		end
	elseif name == "OnInterstitialAdDisplayedEvent" then
		if is_ad_unit_match(params, interstitial_ad_unit_id) then
			interstitial_loaded = false
			if opened_callback then opened_callback() end
		end
	elseif name == "OnInterstitialAdDisplayFailedEvent" then
		if is_ad_unit_match(params, interstitial_ad_unit_id) then
			interstitial_loaded = false
			if error_callback then error_callback() end
			load_interstitial()
		end
	elseif name == "OnInterstitialAdHiddenEvent" then
		if is_ad_unit_match(params, interstitial_ad_unit_id) then
			if close_callback then close_callback() end
			load_interstitial()
		end
	elseif name == "OnBannerAdLoadedEvent" then
		banner_loaded = true
		if is_ad_unit_match(params, banner_ad_unit_id) and banner_loaded and banner_should_show and not banner_showed then
			applovin.show_banner(banner_ad_unit_id)
			banner_showed = true
		end
	elseif name == "OnBannerAdLoadFailedEvent" then
		banner_loaded = false
		if is_ad_unit_match(params, banner_ad_unit_id) and banner_should_show then
			schedule_retry(function()
				M.ads.show_banner(banner_position)
			end)
		end
	elseif name == "OnBannerAdExpandedEvent" then

	elseif name == "OnBannerAdCollapsedEvent" then

	end
end

local function is_reward_ads_available()
	if not applovin then
		return false
	end
	return rewarded_loaded
end

local function is_interstitial_ads_available()
	if not applovin then
		return false
	end
	return interstitial_loaded
end

local function show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback)
	set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
	local ad_unit_id = rewarded_ad_unit_id
	if not applovin or not ad_unit_id or ad_unit_id == "" then
		if _error_callback then _error_callback() end
		return
	end
	if is_reward_ads_available() then
		applovin.show_rewarded_ad(ad_unit_id)
	else
		load_rewarded()
		if _error_callback then _error_callback() end
	end
end

local function show_interstitial_ads(_close_callback, _error_callback, _opened_callback)
	set_up_callbacks(nil, _close_callback, _error_callback, _opened_callback)
	local ad_unit_id = interstitial_ad_unit_id
	if not applovin or not ad_unit_id or ad_unit_id == "" then
		if _error_callback then _error_callback() end
		return
	end
	if is_interstitial_ads_available() then
		applovin.show_interstitial(ad_unit_id)
	else
		load_interstitial()
		if _error_callback then _error_callback() end
	end
end

function M.init_sdk()
	if not sdk_key or sdk_key == "" then
		error("AppLovin sdk_key is not set")
	end
	assert(applovin, "AppLovin sdk not found")

	applovin.set_callback(listener)
	applovin.initialize(sdk_key)
	is_inited = true
	load_rewarded()
	load_interstitial()
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
		return applovin ~= nil and rewarded_ad_unit_id ~= nil and rewarded_ad_unit_id ~= ""
	end,
	is_banner_supported = function()
		return applovin ~= nil and banner_ad_unit_id ~= nil and banner_ad_unit_id ~= ""
	end,
	show_banner = function(position)
		local ad_unit_id = banner_ad_unit_id
		if not ad_unit_id or ad_unit_id == "" then
			return
		end
		if banner_state == "shown" then
			return
		end
		local position_str = "bottom_center"
		if position == "top" then
			position_str = "top_center"
		elseif position == "left" then
			position_str = "center_left"
		elseif position == "right" then
			position_str = "center_right"
		end
		banner_should_show = true
		if not banner_created then
			banner_created = true
			banner_ad_unit_id = ad_unit_id
			banner_position = position_str
			applovin.create_banner(ad_unit_id, position_str)
		end
		banner_state = "shown"
		if banner_loaded then
			applovin.show_banner(ad_unit_id)
			banner_showed = true
		end
	end,
	hide_banner = function()
		if banner_state == "hidden" then
			return
		end
		banner_should_show = false
		banner_state = "hidden"
		if banner_ad_unit_id then
			applovin.hide_banner(banner_ad_unit_id)
			banner_showed = false
		end
	end,
	get_banner_state = function()
		return banner_state
	end
}

M.ads = ads

return M

local ad_timer = require("bridge.ads_utils.ad_timer")
local ad_sound_mute = require("bridge.ads_utils.ad_sound_mute")
local M = {}

M.ads_hide_cb = nil
M.ads_show_cb = nil
M.ADS_KIND_REWARDED = 1
M.ADS_KIND_INTERSTITIAL = 2

---@param is_interstitial_ads_available_main_method function
---@return boolean
function M.is_interstitial_ads_available(is_interstitial_ads_available_main_method)
	if not ad_timer.is_interstitial_allowed_by_time() then
		return false
	end
	return is_interstitial_ads_available_main_method()
end

---@param _reward_callback function | nil
---@param _close_callback function | nil
---@param _error_callback function | nil
---@param _opened_callback function | nil
---@param show_reward_ads_main_method function
function M.show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback, show_reward_ads_main_method)
	local ad_kind = M.ADS_KIND_REWARDED
	local __opened_callback = function()
		ad_timer.reset_rewarded_ad_timer()
		if M.ads_show_cb then M.ads_show_cb(ad_kind) end
		if _opened_callback then _opened_callback() end
	end
	if M.ads_hide_cb then
		local old_close_cb = _close_callback
		_close_callback = function()
			M.ads_hide_cb(ad_kind)
			if old_close_cb then
				old_close_cb()
			end
		end
	end
	local reward_callback, close_callback, error_callback, opened_callback = ad_sound_mute.get_reward_ads_callbacks(_reward_callback, _close_callback, _error_callback, __opened_callback)
	show_reward_ads_main_method(reward_callback, close_callback, error_callback, opened_callback)
end

---@param _close_callback function | nil
---@param _error_callback function | nil
---@param _opened_callback function | nil
---@param show_interstitial_ads_main_method function
function M.show_interstitial_ads(_close_callback, _error_callback, _opened_callback, show_interstitial_ads_main_method)
	local ad_kind = M.ADS_KIND_INTERSTITIAL
	local __opened_callback = function()
		ad_timer.reset_interstitial_timer()
		if M.ads_show_cb then M.ads_show_cb(ad_kind) end
		if _opened_callback then _opened_callback() end
	end
	if M.ads_hide_cb then
		local old_close_cb = _close_callback
		_close_callback = function()
			M.ads_hide_cb(ad_kind)
			if old_close_cb then
				old_close_cb()
			end
		end
	end
	local close_callback, error_callback, opened_callback = ad_sound_mute.get_interstitial_ads_callbacks(_close_callback, _error_callback, __opened_callback)
	show_interstitial_ads_main_method(close_callback, error_callback, opened_callback)
end

return M

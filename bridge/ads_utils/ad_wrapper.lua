local ad_timer = require("bridge.ads_utils.ad_timer")
local ad_sound_mute = require("bridge.ads_utils.ad_sound_mute")
local M = {}

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
	local __opened_callback = function()
		ad_timer.reset_rewarded_ad_timer()
		if _opened_callback then _opened_callback() end
	end
	local reward_callback, close_callback, error_callback, opened_callback = ad_sound_mute.get_reward_ads_callbacks(_reward_callback, _close_callback, _error_callback, __opened_callback)
	show_reward_ads_main_method(reward_callback, close_callback, error_callback, opened_callback)
end

---@param _close_callback function | nil
---@param _error_callback function | nil
---@param _opened_callback function | nil
---@param show_interstitial_ads_main_method function
function M.show_interstitial_ads(_close_callback, _error_callback, _opened_callback, show_interstitial_ads_main_method)
	local __opened_callback = function()
		ad_timer.reset_interstitial_timer()
		if _opened_callback then _opened_callback() end
	end
	local close_callback, error_callback, opened_callback = ad_sound_mute.get_interstitial_ads_callbacks(_close_callback, _error_callback, __opened_callback)
	show_interstitial_ads_main_method(close_callback, error_callback, opened_callback)
end

return M

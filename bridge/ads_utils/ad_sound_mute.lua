local M = {}

M.MUTE_SOUND_ON_ADS = true

---@param reward_callback_param function | nil
---@param close_callback_param function | nil
---@param error_callback_param function | nil
---@param opened_callback_param function | nil
function M.get_reward_ads_callbacks(reward_callback_param, close_callback_param, error_callback_param, opened_callback_param)
	local previous_master_gain = nil
	local reward_callback = nil
	local error_callback = nil
	local close_callback = nil
	local opened_callback = nil

	-- Setup wrapped callbacks with sound management
	if M.MUTE_SOUND_ON_ADS then
		previous_master_gain = sound.get_group_gain("master")

		reward_callback = function()
			if reward_callback_param then reward_callback_param() end
		end

		error_callback = function()
			if M.MUTE_SOUND_ON_ADS and previous_master_gain then
				sound.set_group_gain("master", previous_master_gain)
			end
			if error_callback_param then error_callback_param() end
		end

		close_callback = function()
			if M.MUTE_SOUND_ON_ADS and previous_master_gain then
				sound.set_group_gain("master", previous_master_gain)
			end
			if close_callback_param then close_callback_param() end
		end

		opened_callback = function()
			if M.MUTE_SOUND_ON_ADS then
				sound.set_group_gain("master", 0)
			end
			if opened_callback_param then opened_callback_param() end
		end
	else
		reward_callback = reward_callback_param
		error_callback = error_callback_param
		close_callback = close_callback_param
		opened_callback = opened_callback_param
	end

	return reward_callback, close_callback, error_callback, opened_callback
end

---@param close_callback_param function | nil
---@param error_callback_param function | nil
---@param opened_callback_param function | nil
function M.get_interstitial_ads_callbacks(close_callback_param, error_callback_param, opened_callback_param)
	local previous_master_gain = nil
	local error_callback = nil
	local close_callback = nil
	local opened_callback = nil

	-- Setup wrapped callbacks with sound management
	if M.MUTE_SOUND_ON_ADS then
		previous_master_gain = sound.get_group_gain("master")

		error_callback = function()
			if M.MUTE_SOUND_ON_ADS and previous_master_gain then
				sound.set_group_gain("master", previous_master_gain)
			end
			if error_callback_param then error_callback_param() end
		end

		close_callback = function()
			if M.MUTE_SOUND_ON_ADS and previous_master_gain then
				sound.set_group_gain("master", previous_master_gain)
			end
			if close_callback_param then close_callback_param() end
		end

		opened_callback = function()
			if M.MUTE_SOUND_ON_ADS then
				sound.set_group_gain("master", 0)
			end
			if opened_callback_param then opened_callback_param() end
		end
	else
		close_callback = close_callback_param
		error_callback = error_callback_param
		opened_callback = opened_callback_param
	end
	return close_callback, error_callback, opened_callback
end

return M

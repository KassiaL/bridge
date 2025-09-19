local M = {}

-- Mock state for testing
local rewarded_ad_reward_enabled = false
local is_sdk_inited = false

function M.set_rewarded_ad_reward_enabled(is_enabled)
	rewarded_ad_reward_enabled = is_enabled
end

function M.init_sdk()
	is_sdk_inited = true
end

function M.delay_sdk_init(seconds)
	is_sdk_inited = false
	timer.delay(seconds, false, function()
		M.init_sdk()
	end)
end

function M.is_sdk_inited()
	return is_sdk_inited
end

-- Set up social wrapper directly
---@type social
local social = {
	is_share_supported = function()
		return false
	end,

	share = function() end,

	is_invite_friends_supported = function()
		return false
	end,

	invite_friends = function() end,

	is_add_to_favorites_supported = function()
		return false
	end,

	add_to_favorites = function() end,

	is_add_to_home_screen_supported = function()
		return false
	end,

	add_to_home_screen = function() end,

	is_rate_supported = function()
		return false
	end,

	rate = function() end,
}

M.social = social

M.enable_social = function()
	social.is_share_supported = function()
		return true
	end
	social.is_invite_friends_supported = function()
		return true
	end
	social.is_add_to_favorites_supported = function()
		return true
	end
	social.is_add_to_home_screen_supported = function()
		return true
	end
	social.is_rate_supported = function()
		return true
	end
	social.invite_friends = function(options, success_callback)
		success_callback(true)
	end
	social.share = function(options, success_callback)
		success_callback(true)
	end
	social.add_to_favorites = function(success_callback)
		success_callback(true)
	end
	social.add_to_home_screen = function(success_callback)
		success_callback(true)
	end
	social.rate = function(success_callback)
		success_callback(true)
	end
end

-- Set up storage wrapper directly
---@type storage
local storage = {
	is_supported = function()
		return false
	end,

	set = function() end,

	get = function(key, callback)
		if callback then callback(nil) end
	end,

	set_multiple = function() end,

	get_multiple = function(keys_array, callback)
		if callback then callback(nil) end
	end,
}

M.storage = storage

-- Set up user wrapper directly
---@type user
local user = {
	is_authorization_supported = function()
		return false
	end,

	is_authorized = function()
		return false
	end,

	get_player_id = function()
		return ""
	end,

	get_player_name = function()
		return ""
	end,
}

M.user = user

-- Set up ads wrapper directly
---@type ads
local ads = {
	is_reward_ads_available = function()
		if rewarded_ad_reward_enabled then
			return true
		end
		return false
	end,

	is_interstitial_ads_available = function()
		return false
	end,

	show_reward_ads = function(_reward_callback, _close_callback, _error_callback, _opened_callback)
		if rewarded_ad_reward_enabled then
			if _opened_callback then _opened_callback() end
			if _reward_callback then _reward_callback() end
			if _close_callback then _close_callback() end
		else
			if _error_callback then _error_callback() end
		end
	end,

	show_interstitial_ads = function(_close_callback, _error_callback, _opened_callback)
		if _error_callback then _error_callback() end
	end,
}

M.ads = ads

-- Set up utils wrapper directly
---@type utils
local utils = {
	get_language = function()
		return sys.get_sys_info().language
	end,

	get_server_time = function(callback_millis)
		if callback_millis then callback_millis(socket.gettime()) end
	end,

	send_platform_message = function(message)
		-- Mock implementation does nothing
	end,

	get_platform_id = function()
		return sys.get_sys_info().system_name
	end,

}

M.utils = utils

---@type analytics
local analytics = {
	log_string = function(event, param, value) print("ANALYTICS:", event, param, value) end,
	log_int = function(event, param, value) print("ANALYTICS:", event, param, value) end,
	log_number = function(event, param, value) print("ANALYTICS:", event, param, value) end,
	log_table = function(event, value) print("ANALYTICS:", event, value) end,
	log = function(event) print("ANALYTICS:", event) end,
}

M.analytics = analytics

---@type payments
local payments = {
	is_supported = function()
		return false
	end,
	purchase = function() end,
	get_catalog = function() end,
	set_callback = function() end,
	restore = function() end,
	consume = function() end,
}
M.payments = payments
---@type fun(payment_item_id: string?) | nil
local payments_callback = nil

---@param payments_catalog payment_item[]
M.set_payments_supported_true = function(payments_catalog)
	payments.is_supported = function()
		return true
	end
	payments.set_callback = function(callback)
		payments_callback = callback
	end
	payments.get_catalog = function(purchases_id_list, callback)
		callback(payments_catalog)
	end
	payments.purchase = function(id)
		if payments_callback then payments_callback(id) end
	end
	payments.consume = function(id)
		if payments_callback then payments_callback(id) end
	end
	payments.restore = function()
		for index, value in ipairs(payments_catalog) do
			if payments_callback then
				payments_callback(value.ident)
				print("RESTORED: " .. value.ident)
			end
		end
	end
end

---@type leaderboards
local leaderboards = {
	get_type = function()
		return "not_available"
	end,
	set_score = function() end,
	get_entries = function() end,
	show_native_popup = function() end,
}
M.leaderboards = leaderboards

M.enable_leaderboards = function()
	leaderboards.get_type = function()
		return "in_game"
	end
	leaderboards.get_entries = function(leaderboard_id, callback)
		local entries = {}
		local max_entries = 50
		for i = 1, max_entries do
			local score = max_entries * 2 - i
			local rank = i
			table.insert(entries, {
				id = i,
				name = "Player " .. i,
				photo = "",
				score = score,
				rank = rank,
			})
		end
		callback(entries)
	end
	leaderboards.set_score = function(leaderboard_id, score)

	end
end

return M

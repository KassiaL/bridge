local M = {}
local gamepush = require("gamepush.gamepush")
local mock = require("bridge.mock")

local is_inited = false

local reward_callback = nil
local error_callback = nil
local close_callback = nil
local opened_callback = nil

local function set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
	reward_callback = _reward_callback
	close_callback = _close_callback
	error_callback = _error_callback
	opened_callback = _opened_callback
end

local function ads_start()
	if opened_callback then opened_callback() end
end

local function ads_close(success)
	if close_callback then close_callback() end
	if not success and error_callback then error_callback() end
end

local function ads_reward()
	if reward_callback then reward_callback() end
end

M.pause_callback = nil
M.resume_callback = nil

function M.init_sdk()
	if not gamepush then
		error("gamepush module not found")
	end
	if not gamepush.ads or not gamepush.ads.callbacks then
		error("gamepush ads not available")
	end
	mock.init_sdk()
	gamepush.ads.callbacks.start = ads_start
	gamepush.ads.callbacks.close = ads_close
	gamepush.ads.callbacks.rewarded_reward = ads_reward
	gamepush.init(function(success)
		if success then
			is_inited = true

			local previous_master_gain = 1
			gamepush.callbacks.pause = function()
				sound.set_group_gain("master", 0)
				if M.pause_callback then
					M.pause_callback()
				end
			end
			gamepush.callbacks.resume = function()
				sound.set_group_gain("master", previous_master_gain)
				if M.resume_callback then
					M.resume_callback()
				end
			end
		end
	end)
end

function M.is_sdk_inited()
	return is_inited
end

local function is_reward_ads_available()
	if not gamepush or not gamepush.ads then return false end
	return gamepush.ads.is_rewarded_available()
end

local function is_interstitial_ads_available()
	if not gamepush or not gamepush.ads then return false end
	return gamepush.ads.is_fullscreen_available()
end

local function show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback)
	set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
	if not is_reward_ads_available() then
		if _error_callback then _error_callback() end
		return
	end
	gamepush.ads.show_rewarded_video(function(_) end, {})
end

local function show_interstitial_ads(_close_callback, _error_callback, _opened_callback)
	set_up_callbacks(nil, _close_callback, _error_callback, _opened_callback)
	if not is_interstitial_ads_available() then
		if _error_callback then _error_callback() end
		return
	end
	gamepush.ads.show_fullscreen(function(_) end, {})
end

local ad_wrapper = require("bridge.ads_utils.ad_wrapper")

---@type ads
local ads = {
	is_reward_ads_supported = function()
		return true
	end,
	is_reward_ads_available = is_reward_ads_available,
	is_interstitial_ads_available = function()
		return ad_wrapper.is_interstitial_ads_available(is_interstitial_ads_available)
	end,
	show_reward_ads = function(_reward_callback, _close_callback, _error_callback, _opened_callback)
		ad_wrapper.show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback, show_reward_ads)
	end,
	show_interstitial_ads = function(_close_callback, _error_callback, _opened_callback)
		ad_wrapper.show_interstitial_ads(_close_callback, _error_callback, _opened_callback, show_interstitial_ads)
	end
}

M.ads = ads

---@type analytics
local analytics = {
	log_string = function(event, param, value)
		if not event then return end
		gamepush.analytics.goal(event, value)
	end,
	log_int = function(event, param, value)
		if not event then return end
		gamepush.analytics.goal(event, value)
	end,
	log = function(event)
		if not event then return end
		gamepush.analytics.goal(event, nil)
	end,
	log_number = function(event, param, value)
		if not event then return end
		gamepush.analytics.goal(event, value)
	end,
	log_table = function(event, value)
		if not event then return end
		gamepush.analytics.goal(event, tostring(value))
	end,
}

M.analytics = analytics

---@type social
local social = {
	is_share_supported = function()
		return gamepush.socials.is_supports_share()
	end,
	share = function(options, success_callback)
		gamepush.socials.share(options or {})
		if success_callback then success_callback(true) end
	end,
	is_invite_friends_supported = function()
		return gamepush.socials.is_supports_native_invite()
	end,
	invite_friends = function(options, success_callback)
		gamepush.socials.invite(options or {})
		if success_callback then success_callback(true) end
	end,
	is_add_to_favorites_supported = function()
		return gamepush.app.can_add_shortcut()
	end,
	add_to_favorites = function(success_callback)
		gamepush.app.add_shortcut(function(result)
			if success_callback then success_callback(result == true) end
		end)
	end,
	is_add_to_home_screen_supported = function()
		return gamepush.app.can_add_shortcut()
	end,
	add_to_home_screen = function(success_callback)
		gamepush.app.add_shortcut(function(result)
			if success_callback then success_callback(result == true) end
		end)
	end,
	is_rate_supported = function()
		return gamepush.app.can_request_review()
	end,
	rate = function(success_callback)
		gamepush.app.request_review(function(result)
			if success_callback then success_callback(result == true) end
		end)
	end,
}

M.social = social

---@type user
local user = {
	is_authorization_supported = function()
		return gamepush.platform.has_integrated_auth()
	end,
	is_authorized = function()
		return gamepush.player.is_logged_in()
	end,
	get_player_id = function()
		local v = gamepush.player.id()
		return v and tostring(v) or ""
	end,
	get_player_name = function()
		return gamepush.player.name()
	end,
}

M.user = user

---@type utils
local utils = {
	get_language = function()
		return gamepush.language()
	end,
	get_server_time = function(callback_millis)
		local iso = gamepush.get_server_time()
		if callback_millis then callback_millis(iso) end
	end,
	send_platform_message = function(message)
		if message == "game_ready" then
			gamepush.game_start()
		elseif message == "gameplay_started" then
			gamepush.gameplay_start()
		end
	end,
	get_platform_id = function()
		return gamepush.platform.type()
	end,
	set_platform_pause_callback = function(f)
		M.pause_callback = f
	end,
	set_platform_resume_callback = function(f)
		M.resume_callback = f
	end
}

M.utils = utils

local payments_callback = nil

---@return payment_item
local function standardize_product(item)
	local item_str = json.encode(item)
	-- html5.run("console.log('standardize_product: ' + '" .. item_str .. "')")
	item.ident = item.tag or ""
	item.title = ""
	item.description = ""
	item.currency_code = item.currencySymbol or ""
	item.price = item.price or 0
	item.price_string = tostring(item.price) .. " " .. tostring(item.currency_code)
	return item
end

local function payments_is_supported()
	return gamepush.payments.is_available()
end

local function payments_set_callback(callback)
	payments_callback = callback
end

local gamepush_catalog = nil
local function payments_purchase(id)
	if not id or id == "" then error("invalid product id") end
	if not gamepush_catalog then
		error("gamepush catalog is nil. Call payments.get_catalog() first")
	end
	local product = nil
	for _, p in ipairs(gamepush_catalog) do
		if p.ident == id then
			product = p
			break
		end
	end
	if not product then
		error("product not found in gamepush catalog")
	end
	gamepush.payments.purchase(product, function(result)
		if payments_callback then
			payments_callback(result.product.tag)
		end
	end)
end

local function payments_consume(id)
	if not id or id == "" then error("invalid product id") end
	if not gamepush_catalog then
		error("gamepush catalog is nil. Call payments.get_catalog() first")
	end
	local product = nil
	for _, p in ipairs(gamepush_catalog) do
		if p.ident == id then
			product = p
			break
		end
	end
	if not product then
		error("product not found in gamepush catalog")
	end
	gamepush.payments.consume(product, function(result)
		if payments_callback then
			payments_callback(result.product.tag)
		end
	end)
end

local function payments_get_catalog(purchases_id_list, callback)
	gamepush.payments.fetch_products(function(result)
		local products = result.products or {}
		for _, product in ipairs(products) do
			standardize_product(product)
		end
		gamepush_catalog = products
		callback(products)
	end)
end

---@type payments
local payments = {
	is_supported = payments_is_supported,
	set_callback = payments_set_callback,
	purchase = payments_purchase,
	consume = payments_consume,
	get_catalog = payments_get_catalog,
	restore = nil,
	get_purchases = function(callback)
		local list = gamepush.payments.purchases() or {}
		local ids = {}
		for _, it in ipairs(list) do
			local id = it and it.tag
			if id and type(id) == "string" then
				table.insert(ids, id)
			end
		end
		callback(ids)
	end
}

M.payments = payments

local function lb_get_type()
	return "in_game"
end

local function lb_set_score(leaderboard_id, score)
	if not leaderboard_id or leaderboard_id == "" then error("invalid leaderboard id") end
	gamepush.leaderboard.publish_record({
		tag = leaderboard_id,
		variant = "1",
		record = {
			key = score
		},
		override = true
	}, function(_) end)
end

local function lb_get_entries(leaderboard_id, callback)
	gamepush.leaderboard.fetch_scoped({
		tag = leaderboard_id,
		variant = "1"
	}, function(answer)
		local leaders = answer and answer.topPlayers or {}
		for _, leader in ipairs(leaders) do
			leader.rank = leader.position
			leader.score = leader.key or 0
		end
		callback(leaders or {})
	end)
end

local function lb_show_native_popup(leaderboard_id)
	-- gamepush.leaderboard.open({ tag = leaderboard_id })
end

---@type leaderboards
local leaderboards = {
	get_type = lb_get_type,
	set_score = lb_set_score,
	get_entries = lb_get_entries,
	show_native_popup = lb_show_native_popup,
}

M.leaderboards = leaderboards

local function storage_is_supported()
	if not gamepush or not gamepush.player then return false end
	return true --gamepush.player.has_any_credentials() or gamepush.player.is_logged_in()
end

local function storage_set(key, value)
	if type(value) == "table" then
		error("storage set does not support tables. use json.encode()")
	end
	gamepush.player.set(key, value)
	gamepush.player.sync({ key }, function() end)
end

local function storage_get(key, callback)
	gamepush.player.load(function()
		local v = gamepush.player.get(key)
		if callback then callback(v) end
	end)
end

---@type storage
local storage = {
	is_supported = storage_is_supported,
	set = storage_set,
	get = storage_get,
	set_local = mock.storage.set_local,
	get_local = mock.storage.get_local,
}

M.storage = storage

return M

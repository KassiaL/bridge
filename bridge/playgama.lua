local M = {}
local context = require("bridge.context")

local AD_OPENED = 0
local AD_CLOSED = 1
local AD_REWARDED = 2
local AD_FAILED = 3

local ad_context = nil
local reward_callback = nil
local error_callback = nil
local close_callback = nil
local opened_callback = nil
local other_callbacks = {}
---@diagnostic disable-next-line: undefined-global
local jstodef = jstodef
local contexts = {}

local function to_boolean(value)
    if value == "true" or value == true then
        return true
    else
        return false
    end
end

local callback_counter = 0
local function get_unique_callback_id()
    callback_counter = callback_counter + 1
    return tostring(callback_counter)
end

local function js_listener(self, message_id, message)
    if message_id == "rew_state" then
        local previous_context = context.get_context()
        context.set_context(ad_context)
        if message == AD_OPENED then
            if opened_callback then opened_callback() end
        elseif message == AD_CLOSED then
            if close_callback then close_callback() end
        elseif message == AD_REWARDED then
            if reward_callback then reward_callback() end
        elseif message == AD_FAILED then
            if error_callback then error_callback() end
        end
        context.set_context(previous_context)
    elseif message_id == "inter_state" then
        local previous_context = context.get_context()
        context.set_context(ad_context)
        if message == AD_OPENED then
            if opened_callback then opened_callback() end
        elseif message == AD_CLOSED then
            if close_callback then close_callback() end
        elseif message == AD_FAILED then
            if error_callback then error_callback() end
        end
        context.set_context(previous_context)
    elseif message_id == "other_callback" then
        if not message.type then
            return
        end
        if other_callbacks[message.type] then
            local previous_context = nil
            if contexts[message.type] then
                previous_context = context.get_context()
                context.set_context(contexts[message.type])
            end
            if message.result then
                if type(message.result) == "string" and (message.result == "true" or message.result == "false") then
                    other_callbacks[message.type](to_boolean(message.result))
                else
                    other_callbacks[message.type](message.result)
                end
            else
                other_callbacks[message.type]()
            end
            if message.clear == nil or message.clear == true then
                other_callbacks[message.type] = nil
                contexts[message.type] = nil
            end
            if previous_context then
                context.set_context(previous_context)
            end
        end
    end
end

M.pause_callback = nil
M.resume_callback = nil

local function init_pause_callback()
    local callback_unique_name = get_unique_callback_id()
    local previous_master_gain = 1
    local pause_callback = function(isPaused)
        if isPaused then
            if M.pause_callback then
                M.pause_callback()
            end
        else
            if M.resume_callback then
                M.resume_callback()
            end
        end
    end
    other_callbacks[callback_unique_name] = pause_callback
    html5.run([[bridge.platform.on(bridge.EVENT_NAME.PAUSE_STATE_CHANGED, isPaused => {
        JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: isPaused, clear: false })
    })]])
end

local audio_timer_id = nil
local function init_audio_callback()
    local previous_master_gain = 1
    local callback_unique_name = get_unique_callback_id()
    local audio_callback = function(isEnabled)
        if audio_timer_id then
            timer.cancel(audio_timer_id)
            audio_timer_id = nil
        end
        if isEnabled then
            sound.set_group_gain("master", previous_master_gain)
        else
            audio_timer_id = timer.delay(0, true, function()
                sound.set_group_gain("master", 0)
            end)
        end
    end
    other_callbacks[callback_unique_name] = audio_callback
    html5.run([[bridge.platform.on(bridge.EVENT_NAME.AUDIO_STATE_CHANGED, isEnabled => {
        JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: isEnabled.toString(), clear: false })
            })]])

    audio_callback(to_boolean(html5.run("bridge.platform.isAudioEnabled")))
end

function M.init_sdk()
    if not html5 then
        error("Playgama is only supported in html5")
    end
    if not jstodef then
        error("Playgama requires jstodef")
    end
    jstodef.add_listener(js_listener)

    local timer_handle = nil
    timer_handle = timer.delay(0, true, function()
        if M.is_sdk_inited() then
            assert(timer_handle, "timer_handle is nil")
            timer.cancel(timer_handle)
            timer_handle = nil
            init_audio_callback()
            init_pause_callback()
        end
    end)
end

function M.is_sdk_inited()
    return to_boolean(html5.run("window.is_bridge_inited"))
end

local function get_server_time(callback_millis)
    local callback_unique_name = get_unique_callback_id()
    other_callbacks[callback_unique_name] = callback_millis
    html5.run([[bridge.platform.getServerTime().then(result => {
                        JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: result })
                    }).catch(error => { })]])
end

-- Utility functions for SDK methods

local function lua_table_array_to_js_string(lua_table)
    local js_string = "["
    for _, value in ipairs(lua_table) do
        js_string = js_string .. "'" .. value .. "',"
    end
    if js_string:sub(-1) == "," then
        js_string = js_string:sub(1, -2)
    end
    js_string = js_string .. "]"
    return js_string
end

local function lua_table_to_js_string(lua_table)
    local js_string = "{"
    for k, v in pairs(lua_table) do
        if type(v) == "string" then
            js_string = js_string .. k .. ":'" .. v .. "',"
        elseif type(v) == "number" or type(v) == "boolean" then
            js_string = js_string .. k .. ":" .. tostring(v) .. ","
        end
    end
    if js_string:sub(-1) == "," then
        js_string = js_string:sub(1, -2)
    end
    js_string = js_string .. "}"
    return js_string
end

-- Set up utils wrapper directly
---@type utils
local utils = {
    get_language = function() return html5.run("bridge.platform.language") end,
    get_server_time = get_server_time,
    send_platform_message = function(message) html5.run("bridge.platform.sendMessage('" .. message .. "')") end,
    get_platform_id = function() return html5.run("bridge.platform.id") end,
    set_platform_pause_callback = function(f)
        M.pause_callback = f
    end,
    set_platform_resume_callback = function(f)
        M.resume_callback = f
    end
}

M.utils = utils

local function set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
    ad_context = context.get_context()
    local new_close_cb = function()
        if _close_callback then
            _close_callback()
        end
        utils.send_platform_message("gameplay_started")
        html5.run("try{const c=document.getElementById('canvas');c&&c.focus&&(c.focus(),setTimeout(()=>{c.focus()},50))}catch(e){}")
    end
    local new_error_cb = function()
        if _error_callback then
            _error_callback()
        end
        utils.send_platform_message("gameplay_started")
    end
    local new_opened_cb = function()
        if _opened_callback then
            _opened_callback()
        end
        utils.send_platform_message("gameplay_stopped")
    end
    reward_callback = _reward_callback
    close_callback = new_close_cb
    error_callback = new_error_cb
    opened_callback = new_opened_cb
end

local function is_reward_ads_available()
    return to_boolean(html5.run("bridge.advertisement.isRewardedSupported")) and
        to_boolean(html5.run("bridge.advertisement.rewardedState != \"loading\""))
end

local function is_interstitial_ads_available()
    return to_boolean(html5.run("bridge.advertisement.isInterstitialSupported")) and
        to_boolean(html5.run("bridge.advertisement.interstitialState != \"loading\""))
end

local function show_reward_ads(_reward_callback, _close_callback, _error_callback, _opened_callback)
    set_up_callbacks(_reward_callback, _close_callback, _error_callback, _opened_callback)
    html5.run("bridge.advertisement.showRewarded()")
end

local function show_interstitial_ads(_close_callback, _error_callback, _opened_callback)
    set_up_callbacks(nil, _close_callback, _error_callback, _opened_callback)
    html5.run("bridge.advertisement.showInterstitial()")
end

---@param key string
---@param value string|table
---@param platform_internal boolean
local function storage_set(key, value, platform_internal)
    local platform_internal_str = platform_internal and "platform_internal" or "local_storage"
    if type(value) == "table" then
        error("Storage set does not support tables. Use json.encode() to encode the table.")
    else
        html5.run([[try {bridge.storage.set(']] ..
            key .. [[', ']] .. value .. [[', ']] .. platform_internal_str .. [[').catch(error => { })} catch (error) {}]])
    end
end

---Note that table will be returned as string, so you need to decode it using json.decode()
---@param key string
---@param callback function
---@param platform_internal boolean
local function storage_get(key, callback, platform_internal)
    local callback_unique_name = get_unique_callback_id()
    other_callbacks[callback_unique_name] = callback
    contexts[callback_unique_name] = context.get_context()
    local platform_internal_str = platform_internal and "platform_internal" or "local_storage"
    --use data = data[0]; to get the value Because for some reason playgama returns an array with 1 element
    html5.run([[bridge.storage.get(']] ..
        key ..
        [[', "]] .. platform_internal_str .. [[").then((data) => { JsToDef.send("other_callback", { type: "]] ..
        callback_unique_name ..
        [[", result: data }) }).catch(error => { JsToDef.send("other_callback", { type: "]] ..
        callback_unique_name .. [[" }) })]])
end

-- Social features

local function is_share_supported()
    return to_boolean(html5.run("bridge.social.isShareSupported"))
end

local function share(options, success_callback)
    local callback_success_unique_name = get_unique_callback_id()
    other_callbacks[callback_success_unique_name] = success_callback
    contexts[callback_success_unique_name] = context.get_context()

    local js_options = ""
    if options then
        js_options = lua_table_to_js_string(options)
    end

    local js_code = [[
        bridge.social.share(]] .. (js_options ~= "" and js_options or "{}") .. [[)
            .then(() => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: true });
            })
            .catch(error => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: false });
            });
    ]]

    html5.run(js_code)
end

local function is_invite_friends_supported()
    return to_boolean(html5.run("bridge.social.isInviteFriendsSupported"))
end

local function invite_friends(options, success_callback)
    local callback_success_unique_name = get_unique_callback_id()
    other_callbacks[callback_success_unique_name] = success_callback
    contexts[callback_success_unique_name] = context.get_context()

    local js_options = ""
    if options then
        js_options = lua_table_to_js_string(options)
    end

    local js_code = [[
        bridge.social.inviteFriends(]] .. (js_options ~= "" and js_options or "{}") .. [[)
            .then(() => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: true });
            })
            .catch(error => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: false });
            });
    ]]

    html5.run(js_code)
end

local function is_add_to_favorites_supported()
    return to_boolean(html5.run("bridge.social.isAddToFavoritesSupported"))
end

local function add_to_favorites(success_callback)
    local callback_success_unique_name = get_unique_callback_id()
    other_callbacks[callback_success_unique_name] = success_callback
    contexts[callback_success_unique_name] = context.get_context()

    local js_code = [[
        bridge.social.addToFavorites()
            .then(() => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: true });
            })
            .catch(error => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: false });
            });
    ]]

    html5.run(js_code)
end

local function is_add_to_home_screen_supported()
    return to_boolean(html5.run("bridge.social.isAddToHomeScreenSupported"))
end

local function add_to_home_screen(success_callback)
    local callback_success_unique_name = get_unique_callback_id()
    other_callbacks[callback_success_unique_name] = success_callback
    contexts[callback_success_unique_name] = context.get_context()

    local js_code = [[
        bridge.social.addToHomeScreen()
            .then(() => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: true });
            })
            .catch(error => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: false });
            });
    ]]

    html5.run(js_code)
end

local function is_rate_supported()
    return to_boolean(html5.run("bridge.social.isRateSupported"))
end

local function rate(success_callback)
    local callback_success_unique_name = get_unique_callback_id()
    other_callbacks[callback_success_unique_name] = success_callback
    contexts[callback_success_unique_name] = context.get_context()

    local js_code = [[
        bridge.social.rate()
            .then(() => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: true });
            })
            .catch(error => {
                JsToDef.send("other_callback", { type: "]] .. callback_success_unique_name .. [[", result: false });
            });
    ]]

    html5.run(js_code)
end

-- Set up social wrapper directly
---@type social
local social = {
    is_share_supported = is_share_supported,
    share = share,
    is_invite_friends_supported = is_invite_friends_supported,
    invite_friends = invite_friends,
    is_add_to_favorites_supported = is_add_to_favorites_supported,
    add_to_favorites = add_to_favorites,
    is_add_to_home_screen_supported = is_add_to_home_screen_supported,
    add_to_home_screen = add_to_home_screen,
    is_rate_supported = is_rate_supported,
    rate = rate
}

M.social = social

-- Set up storage wrapper directly
---@type storage
local storage = {
    is_supported = function()
        local supported = to_boolean(html5.run("bridge.storage.isSupported(\"platform_internal\")"))
        local available = to_boolean(html5.run("bridge.storage.isAvailable(\"platform_internal\")"))
        return supported and available
    end,
    set = function(key, value)
        storage_set(key, value, true)
    end,
    get = function(key, callback)
        storage_get(key, callback, true)
    end,
    set_local = function(key, value)
        storage_set(key, value, false)
    end,
    get_local = function(key, callback)
        storage_get(key, callback, false)
    end
}

M.storage = storage

-- Set up user wrapper directly
---@type user
local user = {
    is_authorization_supported = function() return to_boolean(html5.run("bridge.player.isAuthorizationSupported")) end,
    is_authorized = function() return to_boolean(html5.run("bridge.player.isAuthorized")) end,
    get_player_id = function() return html5.run("bridge.player.id") end,
    get_player_name = function() return html5.run("bridge.player.name") end,
}

M.user = user

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
        return to_boolean(html5.run("bridge.advertisement.isRewardedSupported"))
    end
}

M.ads = ads

local function is_payments_supported()
    return to_boolean(html5.run("bridge.payments.isSupported"))
end

if html5 then
    html5.run([[window.standardize_purchase = function(purchase) {
	purchase.ident = purchase.id
	purchase.id = null
	purchase.currency_code = purchase.priceCurrencyCode
	purchase.priceCurrencyCode = null
	purchase.price_string = purchase.price
	purchase.price = purchase.priceValue
	purchase.priceValue = null
	purchase.title = ""
	purchase.description = ""
}]])
end

local inapp_unique_callback_id = nil

local function purchase(id)
    local callback_unique_name = inapp_unique_callback_id
    html5.run([[bridge.payments.purchase("]] .. id .. [[")
		.then((purchase) => {
			//window.standardize_purchase(purchase) don't need to standardize. Use purchase.id instead
			JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: purchase.id })
		})
		.catch(error => {
			JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: undefined })
		})
	]])
end

local function get_catalog(purchases_id_list, callback)
    local callback_unique_name = get_unique_callback_id()
    other_callbacks[callback_unique_name] = callback
    html5.run([[bridge.payments.getCatalog()
    .then(catalogItems => {
		for (let i = 0; i < catalogItems.length; i++) {
			window.standardize_purchase(catalogItems[i])
		}
		JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: catalogItems })
    })
    .catch(error => {
		JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: [] })
    })]])
end

local function consume(id)
    local callback_unique_name = inapp_unique_callback_id
    html5.run([[bridge.payments.consumePurchase("]] .. id .. [[")
		.then((purchase) => {
			JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: purchase.id })
		})
		.catch(error => {
			JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: undefined })
		})
	]])
end

---@type payments
local payments = {
    is_supported = is_payments_supported,
    purchase = purchase,
    consume = consume,
    get_catalog = get_catalog,
    set_callback = function(callback)
        inapp_unique_callback_id = get_unique_callback_id()
        other_callbacks[inapp_unique_callback_id] = callback
    end,
    restore = nil,
    get_purchases = function(callback)
        local callback_unique_name = get_unique_callback_id()
        other_callbacks[callback_unique_name] = callback
        html5.run([[bridge.payments.getPurchases().then(purchases => {
            const ids = []
            purchases.forEach(purchase => {
                ids.push(purchase.id)
            })
            JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: ids })
        }).catch(error => {
            JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: [] })
        })]])
    end
}

M.payments = payments

---@type leaderboards
local leaderboards = {
    get_type = function()
        return html5.run("bridge.leaderboards.type")
    end,
    set_score = function(leaderboard_id, score)
        if user.is_authorization_supported() and user.is_authorized() then
            html5.run([[bridge.leaderboards.setScore("]] ..
                leaderboard_id .. [[", ]] .. score .. [[).catch(error => { })]])
        end
    end,
    get_entries = function(leaderboard_id, callback)
        local callback_unique_name = get_unique_callback_id()
        other_callbacks[callback_unique_name] = callback
        html5.run([[bridge.leaderboards.getEntries("]] .. leaderboard_id .. [[").then(entries => {
			JsToDef.send("other_callback", { type: "]] .. callback_unique_name .. [[", result: entries })
		}).catch(error => { })]])
    end,
    show_native_popup = function(leaderboard_id)
        html5.run([[bridge.leaderboards.showNativePopup("]] .. leaderboard_id .. [[").catch(error => { })]])
    end,
}

M.leaderboards = leaderboards

return M

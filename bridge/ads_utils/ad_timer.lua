local M = {}

local last_interstitial_time = 0
local last_rewarded_ad_time = 0
M.INTERSTITIAL_COOLDOWN = 150
M.INTERSTITIALL_COOLDOWN_DUE_REWARDED_AD = M.INTERSTITIAL_COOLDOWN
M.INITIAL_DELAY = 100
local game_start_time = socket.gettime()
local manual_delay_until = 0

local function reset_interstitial_timer()
	last_interstitial_time = socket.gettime()
end

local function reset_rewarded_ad_timer()
	last_rewarded_ad_time = socket.gettime()
end

local function is_interstitial_allowed_by_time()
	local current_time = socket.gettime()
	if current_time < manual_delay_until then
		return false
	end
	if current_time - game_start_time < M.INITIAL_DELAY then
		return false
	end
	if current_time - last_interstitial_time < M.INTERSTITIAL_COOLDOWN then
		return false
	end
	if current_time - last_rewarded_ad_time < M.INTERSTITIALL_COOLDOWN_DUE_REWARDED_AD then
		return false
	end
	return true
end

M.reset_interstitial_timer = reset_interstitial_timer
M.reset_rewarded_ad_timer = reset_rewarded_ad_timer
M.is_interstitial_allowed_by_time = is_interstitial_allowed_by_time

---@param seconds number
function M.delay_interstitial(seconds)
	local current_time = socket.gettime()
	local new_delay_time = current_time + seconds
	if new_delay_time > manual_delay_until then
		manual_delay_until = new_delay_time
	end
end

return M

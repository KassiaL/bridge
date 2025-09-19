local M = {}

local current_sdk = nil
local sdks = {}

---@type analytics
M.analytics = nil

---@type social
M.social = nil

---@type storage
M.storage = nil

---@type user
M.user = nil

---@type ads
M.ads = nil

---@type utils
M.utils = nil

---@type payments
M.payments = nil

---@type leaderboards
M.leaderboards = nil

---@param sdk table
local function validate_sdk(sdk)
	assert(sdk.is_sdk_inited, "Sdk " .. tostring(sdk) .. " do not have is_sdk_inited method")
	assert(sdk.init_sdk, "Sdk " .. tostring(sdk) .. " do not have init_sdk method")
end

---Initialize SDKs. The next sdk will not overwrite the methods of the previous one. The init_sdk method will be called for each sdk.
---example:
---bridge.init_sdks({
---	firebase,
---	appodeal,
--- mock
---})
---@param sdk_modules table[]
function M.init_sdks(sdk_modules)
	if current_sdk then
		error("Sdk already inited")
	end
	current_sdk = {}
	for _, sdk_module in ipairs(sdk_modules) do
		for k, v in pairs(sdk_module) do
			if not current_sdk[k] then
				current_sdk[k] = v
			end
			if k == "init_sdk" then
				v()
			end
		end
		table.insert(sdks, sdk_module)
		validate_sdk(sdk_module)
	end

	for k, v in pairs(current_sdk) do
		if k ~= "init_sdk" then
			M[k] = v
		end
	end
end

---@return boolean
function M.is_all_sdk_inited()
	if not current_sdk then
		error("Sdk not inited. Use bridge.init_sdk() first")
	end
	for _, sdk in ipairs(sdks) do
		if not sdk.is_sdk_inited() then
			return false
		end
	end
	return true
end

---@param callback function
function M.run_after_sdk_init(callback, ...)
	local args = { ... }
	local log_timer = nil
	local log = function()
		if M.is_all_sdk_inited() then
			---@diagnostic disable-next-line: param-type-mismatch
			timer.cancel(log_timer)
			callback(unpack(args))
		end
	end
	log_timer = timer.delay(0, true, log)
end

return M

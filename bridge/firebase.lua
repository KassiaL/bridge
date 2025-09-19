local M = {}
---@diagnostic disable-next-line: undefined-global
local firebase = firebase

if not firebase then
	return
end

local is_inited = false

local function firebase_analytics_callback(self, message_id, message)
	if message_id == firebase.analytics.MSG_ERROR then
		-- an error was detected when performing an analytics config operation
		print("Firebase Analytics Config error: ", message.error)
		return
	end

	if message_id == firebase.analytics.MSG_INSTANCE_ID then
		-- result of the firebase.analytics.get_id() call
		print("Firebase Analytics Config instance_id: ", message.instance_id)
		return
	end
end

function M.init_sdk()
	if not firebase then
		return
	end

	-- initialise firebase and check that it was successful
	firebase.set_callback(function(self, message_id, message)
		if message_id == firebase.MSG_INITIALIZED then
			firebase.analytics.set_callback(firebase_analytics_callback)
			firebase.analytics.initialize()
			is_inited = true
			-- firebase.analytics.get_id()
		end
	end)
	firebase.initialize()
end

function M.is_sdk_inited()
	return is_inited
end

---@type analytics
local analytics = {
	log_string = firebase.analytics.log_string,
	log_int = firebase.analytics.log_int,
	log = firebase.analytics.log,
	log_number = firebase.analytics.log_number,
	log_table = firebase.analytics.log_table,
}

M.analytics = analytics

return M

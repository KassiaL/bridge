---@alias platform_message "gameplay_started" | "gameplay_stopped" | "game_ready" | "in_game_loading_started" | "in_game_loading_stopped" | "player_got_achievement"

---@class utils
---@field get_language fun(): string
---@field get_server_time fun(callback_millis: function)
---@field send_platform_message fun(message: platform_message)
---@field get_platform_id fun(): string
---@field set_platform_resume_callback fun(f: fun())
---@field set_platform_pause_callback fun(f: fun())

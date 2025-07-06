local config = require("log.internal.config")
local formatter = require("log.internal.formatter")

local M = {}

---@class log.state
---@field logs table<string, number>
M.STATE = {
	logs = sys.load(config.SAVE_PATH) or {}
}

local FILE_HANDLERS = {}


---Internal log callback for file writing
---@param logger table Logger instance
---@param level string Log level
---@param message string Original message
---@param context any Additional context
---@param log_message string Formatted log message
function M.log_callback(logger, level, message, context, log_message)
	if logger.file then
		if not FILE_HANDLERS[logger.file] then
			FILE_HANDLERS[logger.file] = io.open(logger.file, "a")
		end

		local handler = FILE_HANDLERS[logger.file]
		if handler then
			handler:write(log_message .. "\n")
			handler:flush()

			M.STATE.logs[logger.file] = socket.gettime()
			sys.save(config.SAVE_PATH, M.STATE.logs)
		end
	end
end


---Write log message to file nearby the calling script
---@param logger table Logger instance
function M.write_nearby_this_file(logger)
	local project_path = M.get_current_project_folder()
	if not project_path then
		return
	end

	local file_path = debug.getinfo(3, "S").short_src
	local folder_path = string.match(file_path, "(.+)/[^/]+$")

	local name = logger.name
	if name == config.AUTO_NAME then
		name = formatter.get_default_logger_name(debug.getinfo(3, "S"))
	end

	logger.file = string.format("%s/%s/%s.log", project_path, folder_path, name)
end


---Get current project folder
---@return string|nil
function M.get_current_project_folder()
	if not io.popen or html5 then
		return nil
	end

	local file = io.popen("pwd")
	if not file then
		return nil
	end

	local pwd = file:read("*l")
	file:close()

	if not pwd then
		return nil
	end

	-- Check the game.project file exists in this folder
	local game_project_path = pwd .. "/game.project"
	local game_project_file = io.open(game_project_path, "r")
	if not game_project_file then
		return nil
	end

	game_project_file:close()
	return pwd
end


---Clear all log files
function M.clear_log_files()
	for file, _ in pairs(M.STATE.logs) do
		local is_ok, err = os.remove(file)
		if not is_ok then
			print(err)
		end
	end

	M.STATE.logs = {}
	sys.save(config.SAVE_PATH, M.STATE.logs)
end


---Close all log files
function M.close_log_files()
	for _, handler in pairs(FILE_HANDLERS) do
		handler:flush()
		handler:close()
	end

	FILE_HANDLERS = {}
end

return M

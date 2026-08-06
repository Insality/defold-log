local config = require("log.internal.config")
local formatter = require("log.internal.formatter")

local M = {}

---@class log.state
---@field logs table<string, number>
M.STATE = {
	logs = sys.load(config.SAVE_PATH) or {}
}

-- Global file path for all loggers (nil = disabled)
M.global_file = nil

-- file path -> file handle, or false if open previously failed
local FILE_HANDLERS = {}


local function save_state()
	sys.save(config.SAVE_PATH, M.STATE.logs)
end


---Return true if path looks like a native OS absolute path (Windows drive).
---Defold-style paths like `/logs/game.log` are treated as project-relative.
---@param path string
---@return boolean
local function is_windows_absolute(path)
	return path:match("^%a:[/\\]") ~= nil
end


---Ensure parent directory exists for a file path
---@param filepath string
local function ensure_parent_dir(filepath)
	local dir = filepath:match("(.+)[/\\][^/\\]+$")
	if not dir then
		return
	end

	if config.SYSTEM_NAME == "Windows" then
		os.execute('mkdir "' .. dir:gsub("/", "\\") .. '"')
	else
		os.execute('mkdir -p "' .. dir .. '"')
	end
end


---Resolve a log file path:
--- Windows absolute → as-is
--- Defold `/logs/x` or relative `logs/x` → project/logs/x (editor) or save file (device)
---@param path string
---@return string|nil
function M.resolve_path(path)
	if not path or path == "" then
		return nil
	end

	if is_windows_absolute(path) then
		return path
	end

	-- Strip Defold-style leading slash: /logs/game.log → logs/game.log
	local relative = path:gsub("^/+", "")

	local project_path = M.get_current_project_folder()
	if project_path then
		return project_path .. "/" .. relative
	end

	-- Device / no project folder: store under save directory
	return sys.get_save_file(config.APP_NAME, relative)
end


---Open (or reuse) a file handler and write one log line
---@param path string
---@param log_message string
local function write_to_file(path, log_message)
	local handler = FILE_HANDLERS[path]
	if handler == nil then
		ensure_parent_dir(path)
		handler = io.open(path, "a")
		-- Cache failures as false to avoid retrying open on every log
		FILE_HANDLERS[path] = handler or false
		if handler then
			M.STATE.logs[path] = socket.gettime()
			save_state()
		end
	end

	if handler then
		handler:write(log_message, "\n")
		handler:flush()
		M.STATE.logs[path] = socket.gettime()
	end
end


---Internal log callback for file writing
---@param logger table Logger instance
---@param level string Log level
---@param message string Original message
---@param context any Additional context
---@param log_message string Formatted log message
function M.log_callback(logger, level, message, context, log_message)
	if logger.file then
		write_to_file(logger.file, log_message)
	end

	if M.global_file then
		write_to_file(M.global_file, log_message)
	end
end


---Set global file for all loggers. Pass nil to disable.
---@param path string|nil Relative to project (editor) / save dir (device), or absolute
---@return string|nil resolved_path
function M.set_file(path)
	if not path then
		M.global_file = nil
		return nil
	end

	M.global_file = M.resolve_path(path)
	return M.global_file
end


---Get current global file path (resolved), or nil
---@return string|nil
function M.get_file()
	return M.global_file
end


---Write this logger's messages to a .log file next to the calling script.
---File name is always the script basename (e.g. example.gui_script → example.log).
---@param logger table Logger instance
---@param debuginfo debuginfo Caller debug info
function M.write_nearby_this_file(logger, debuginfo)
	local project_path = M.get_current_project_folder()
	if not project_path then
		return
	end

	local file_path = debuginfo.short_src
	local folder_path = string.match(file_path, "(.+)/[^/]+$")
	if not folder_path then
		return
	end

	local name = formatter.get_default_logger_name(debuginfo)
	logger.file = string.format("%s/%s/%s.log", project_path, folder_path, name)
end


---Get current project folder (editor / desktop only; requires `pwd` and game.project nearby)
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


---Clear all known log files (global + per-logger)
function M.clear_log_files()
	for file, _ in pairs(M.STATE.logs) do
		os.remove(file)
	end

	M.STATE.logs = {}
	save_state()
end


---Close all log files and persist known log paths
function M.close_log_files()
	for path, handler in pairs(FILE_HANDLERS) do
		if handler then
			handler:flush()
			handler:close()
		end
		FILE_HANDLERS[path] = nil
	end

	save_state()
end


-- Auto-enable from game.project: [log] file = path
if config.LOG_FILE and config.LOG_FILE ~= "" then
	M.set_file(config.LOG_FILE)
end


return M

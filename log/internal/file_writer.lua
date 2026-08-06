local config = require("log.internal.config")
local formatter = require("log.internal.formatter")

local M = {}

-- Log file shared by all loggers, nil when disabled
local global_file = nil

-- Resolved file path -> file handler, or false if the file can't be opened
local FILE_HANDLERS = {}

-- Personal log file of a logger. Weak keys, since it should not keep a logger alive.
-- It's a separate table and not a logger field, because all loggers inherit
-- the fields of the log module and would share its file
local LOGGER_FILES = setmetatable({}, { __mode = "k" })

-- Every log file we ever created. Persisted between the game launches,
-- so clear_log_files can remove the files from the previous sessions
local known_files = sys.load(config.STATE_PATH) or {}

-- Project folder, resolved once. False means "checked, not available"
local project_folder = nil


---Close and forget a single cached file handler
---@param path string
local function close_handler(path)
	local handler = FILE_HANDLERS[path]
	if handler then
		handler:flush()
		handler:close()
	end

	FILE_HANDLERS[path] = nil
end


---Create the parent folder for a file path. Desktop only, on the devices
---the save folder already exists and there is no shell to call
---@param filepath string
local function ensure_parent_dir(filepath)
	local dir = filepath:match("(.+)[/\\][^/\\]+$")
	if not dir or config.IS_MOBILE then
		return
	end

	if config.SYSTEM_NAME == "Windows" then
		-- Windows mkdir creates the intermediate folders on its own
		os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>nul')
	else
		os.execute('mkdir -p "' .. dir .. '"')
	end
end


---Open (or reuse) a file handler and append one log line
---@param path string
---@param log_message string
local function write_to_file(path, log_message)
	local handler = FILE_HANDLERS[path]

	if handler == nil then
		handler = io.open(path, "a")
		if not handler then
			-- The folder may not exist yet: create it and retry once
			ensure_parent_dir(path)
			handler = io.open(path, "a")
		end

		-- Cache the failure as false to not retry the open on every message
		FILE_HANDLERS[path] = handler or false

		if handler then
			known_files[path] = true
			sys.save(config.STATE_PATH, known_files)
		end
	end

	if handler then
		handler:write(log_message, "\n")
		handler:flush()
	end
end


---Resolve a relative log path: project folder in the editor, save folder on a device.
---The leading `/` is optional Defold sugar and is stripped.
---@param path string
---@return string|nil
local function resolve_path(path)
	if not path or path == "" then
		return nil
	end

	local relative = path:gsub("^/+", "")
	local project_path = M.get_current_project_folder()

	return project_path and (project_path .. "/" .. relative) or sys.get_save_file(config.APP_NAME, relative)
end


---Get the project folder. Editor and desktop builds only: it takes the shell
---working directory and checks that game.project is there
---@return string|nil
function M.get_current_project_folder()
	if project_folder ~= nil then
		return project_folder or nil
	end

	project_folder = false

	if io.popen and not html5 then
		local file = io.popen(config.SYSTEM_NAME == "Windows" and "cd" or "pwd")
		local pwd = file and file:read("*l")
		if file then
			file:close()
		end

		if pwd and pwd ~= "" then
			-- Normalize Windows paths that may use backslashes
			pwd = pwd:gsub("\\", "/")

			local game_project = io.open(pwd .. "/game.project", "r")
			if game_project then
				game_project:close()
				project_folder = pwd
			end
		end
	end

	return project_folder or nil
end


---Write a formatted message to the personal logger file and to the shared one
---@param logger logger Logger instance
---@param log_message string Formatted log message
function M.on_log(logger, log_message)
	local logger_file = LOGGER_FILES[logger]

	if logger_file then
		write_to_file(logger_file, log_message)
	end

	if global_file and global_file ~= logger_file then
		write_to_file(global_file, log_message)
	end
end


---Set the log file for all loggers. Pass nil to disable
---@param path string|nil Relative path, the leading `/` is optional
---@return string|nil resolved_path
function M.set_file(path)
	local previous = global_file
	global_file = path and resolve_path(path) or nil

	if previous and previous ~= global_file then
		close_handler(previous)
	end

	return global_file
end


---Get the current global log file path (resolved), or nil
---@return string|nil
function M.get_file()
	return global_file
end


---Write this logger messages to a `<logger_name>.log` file next to the calling script
---@param logger logger Logger instance
---@param debuginfo debuginfo|nil Caller debug info
---@return string|nil resolved_path
function M.set_file_nearby(logger, debuginfo)
	local project_path = M.get_current_project_folder()
	local script_path = debuginfo and debuginfo.short_src
	if not project_path or not script_path then
		return nil
	end

	-- Support / and \ ; scripts in the project root use the project folder itself
	local folder_path = string.match(script_path, "(.+)[/\\][^/\\]+$") or "."

	local name = logger.name
	if not name or name == "" or name == config.AUTO_NAME then
		name = formatter.get_default_logger_name(debuginfo)
	end

	LOGGER_FILES[logger] = string.format("%s/%s/%s.log", project_path, folder_path, name)
	return LOGGER_FILES[logger]
end


---Delete all known log files from the disk
function M.clear_log_files()
	-- Close the handlers first, so the remove works on Windows and does not
	-- leave the writers attached to the deleted files on Unix
	M.close_log_files()

	for path, _ in pairs(known_files) do
		os.remove(path)
	end

	known_files = {}
	sys.save(config.STATE_PATH, known_files)
end


---Flush and close all opened log files
function M.close_log_files()
	for path, _ in pairs(FILE_HANDLERS) do
		close_handler(path)
	end
end


-- Auto enable the global log file from game.project: [log] file = path
if config.LOG_FILE ~= "" then
	M.set_file(config.LOG_FILE)
end


return M

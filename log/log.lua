local config = require("log.internal.config")
local formatter = require("log.internal.formatter")
local file_writer = require("log.internal.file_writer")

---@alias logger log

---@overload fun(name: string?, force_logger_level_in_debug: string?): logger
---@class log
---@field name string
---@field level string
---@field file string|nil
---@field private _last_gc_memory number|nil
---@field private _last_message_time number|nil
local M = {}
local METATABLE = { __index = M }

-- Use file_writer's state
M.STATE = file_writer.STATE

-- Internal callbacks (e.g. file writer) are not affected by clear_callbacks
local internal_callbacks = {
	file_writer.log_callback
}

-- User-defined callbacks
local user_callbacks = {}


---Format log message
---@private
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@param caller_info debuginfo
---@return string
function M:format(level, message, context, caller_info)
	return formatter.format(self, level, message, context, caller_info)
end


---Log message with specified level and message
---@private
---@param level string One of the next level: TRACE, DEBUG, INFO, WARN, ERROR
---@param message string? The log message.
---@param context any Additional data to include with the log message.
function M:log(level, message, context)
	if config.LEVEL_PRIORITY[level] > config.LEVEL_PRIORITY[self.level] then
		return nil
	end

	if message then
		-- Capture caller here (public method -> log -> user) so formatting
		-- does not depend on stack depth / tail-call optimizations.
		local caller_info = debug.getinfo(3, "Sl")
		local log_message = self:format(level, message, context, caller_info)

		if config.IS_MOBILE then
			print(log_message)
		else
			io.stdout:write(log_message, "\n")
			io.stdout:flush()
		end

		-- Call internal and user callbacks
		for index = 1, #internal_callbacks do
			internal_callbacks[index](self, level, message, context, log_message)
		end
		for index = 1, #user_callbacks do
			user_callbacks[index](self, level, message, context, log_message)
		end
	end

	if config.IS_MEMORY_TRACK then
		self._last_gc_memory = collectgarbage("count")
	end

	if config.IS_TIME_TRACK then
		self._last_message_time = socket.gettime()
	end

	if config.IS_CHRONOS_TRACK then
		self._last_message_time = chronos.nanotime()
	end
end


---Add a custom handler for log messages
---@param callback fun(logger: logger, level: string, message: string, context: any, log_message: string)
function M.add_callback(callback)
	assert(type(callback) == "function", "Callback must be a function")
	table.insert(user_callbacks, callback)
end


---Remove a specific user callback
---@param callback function The callback function to remove
function M.remove_callback(callback)
	for i, cb in ipairs(user_callbacks) do
		if cb == callback then
			table.remove(user_callbacks, i)
			break
		end
	end
end


---Clear all user callbacks (internal callbacks such as file writing are preserved)
function M.clear_callbacks()
	user_callbacks = {}
end


---Log message with TRACE level
---@param message string? Message to log. Nil still updates memory/time tracking.
---@param data any Additional context data
function M:trace(message, data)
	self:log(config.TRACE, message, data)
end


---Log message with DEBUG level
---@param message string? Message to log. Nil still updates memory/time tracking.
---@param data any Additional context data
function M:debug(message, data)
	self:log(config.DEBUG, message, data)
end


---Log message with INFO level
---@param message string? Message to log. Nil still updates memory/time tracking.
---@param data any Additional context data
function M:info(message, data)
	self:log(config.INFO, message, data)
end


---Log message with WARN level
---@param message string? Message to log. Nil still updates memory/time tracking.
---@param data any Additional context data
function M:warn(message, data)
	self:log(config.WARN, message, data)
end


---Log message with ERROR level
---@param message string? Message to log. Nil still updates memory/time tracking.
---@param data any Additional context data
function M:error(message, data)
	self:log(config.ERROR, message, data)
end


---Enable writing this logger's messages to a .log file next to the calling script.
---Works in editor/desktop only (needs project folder via `pwd`).
function M:write_nearby_this_file()
	file_writer.write_nearby_this_file(self, debug.getinfo(2, "S"))
end


---Set a global file sink for ALL loggers (in addition to console / per-logger files).
---Relative paths: project folder in editor, `sys.get_save_file` on device.
---Pass nil to disable.
---@param path string|nil
---@return string|nil resolved_path
function M.set_file(path)
	return file_writer.set_file(path)
end


---Get current global log file path (resolved), or nil if disabled
---@return string|nil
function M.get_file()
	return file_writer.get_file()
end


---Get current project folder
---@return string|nil
function M.get_current_project_folder()
	return file_writer.get_current_project_folder()
end


---Return the new logger instance
---@param logger_name string|nil
---@param force_logger_level_in_debug string|nil Default is DEBUG, values: FATAL, ERROR, WARN, INFO, DEBUG, TRACE
---@return logger
function M.get_logger(logger_name, force_logger_level_in_debug)
	local instance = {
		name = logger_name or formatter.get_default_logger_name(debug.getinfo(2, "S")),
		level = force_logger_level_in_debug or config.GAME_LOG_LEVEL,
		file = nil,
		_last_gc_memory = nil,
		_last_message_time = nil,
	}

	if config.IS_CHRONOS_TRACK then
		instance._last_message_time = chronos.nanotime()
	end

	if not config.IS_DEBUG then
		if config.LEVEL_PRIORITY[instance.level] < config.LEVEL_PRIORITY[config.GAME_LOG_LEVEL] then
			instance.level = config.GAME_LOG_LEVEL
		end
	end

	return setmetatable(instance, METATABLE)
end


---Delete all known logger .log files from disk
function M.clear_log_files()
	file_writer.clear_log_files()
end


---Flush and close all open logger file handlers.
---Call once on application shutdown (e.g. from your main/bootstrap script `final`).
function M.final()
	file_writer.close_log_files()
end


---Return the basename of the current file
---@private
---@param debuginfo debuginfo
---@return string
function M.get_default_logger_name(debuginfo)
	return formatter.get_default_logger_name(debuginfo)
end


-- Set up the default logger instance
M.name = config.AUTO_NAME
M.level = config.GAME_LOG_LEVEL
M.file = nil
M._last_gc_memory = nil
M._last_message_time = nil

return setmetatable(M, {
	__call = function(_, name, force_logger_level_in_debug)
		if not name then
			name = formatter.get_default_logger_name(debug.getinfo(2, "S"))
		end
		return M.get_logger(name, force_logger_level_in_debug)
	end
})

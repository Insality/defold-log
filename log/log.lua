local config = require("log.internal.config")
local formatter = require("log.internal.formatter")
local file_writter = require("log.internal.file_writter")

---@alias logger log

---@overload fun(name: string, force_logger_level_in_debug: string): logger
---@class log
---@field name string
---@field level string
---@field file string
---@field private _last_gc_memory number
---@field private _last_message_time number
local M = {}

-- Use file_writter's state
M.STATE = file_writter.STATE

-- Custom callback for log messages
local log_callback = nil


---Format log message
---@private
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@return string
function M:format(level, message, context)
	return formatter.format(self, level, message, context)
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
		local log_message = self:format(level, message, context)

		if config.IS_MOBILE then
			print(log_message)
		else
			io.stdout:write(log_message, "\n")
			io.stdout:flush()
		end

		file_writter.internal_log_callback(self, level, message, context, log_message)

		-- Additionally call custom callback if set
		if log_callback then
			log_callback(self, level, message, context, log_message)
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


---Set a custom handler for log messages, only one callback can be set
---@param callback function|nil Function that receives (logger, level, message, context, log_message)
function M.set_callback(callback)
	log_callback = callback
end


---Log message with TRACE level
---@param message string? Message to log
---@param data any
function M:trace(message, data)
	self:log(config.TRACE, message, data)
end


---Log message with DEBUG level
---@param data any
---@param message string Message to log
function M:debug(message, data)
	self:log(config.DEBUG, message, data)
end


---Log message with INFO level
---@param message string
---@param data any
function M:info(message, data)
	self:log(config.INFO, message, data)
end


---Log message with WARN level
---@param message string
---@param data any
function M:warn(message, data)
	self:log(config.WARN, message, data)
end


---Log message with ERROR level
---@param message string
---@param data any
function M:error(message, data)
	self:log(config.ERROR, message, data)
end


---Write log message to file
function M:write_nearby_this_file()
	file_writter.write_nearby_this_file(self)
end


---Get current project folder
function M.get_current_project_folder()
	return file_writter.get_current_project_folder()
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

	return setmetatable(instance, { __index = M })
end


---Clear all log files
function M.clear_log_files()
	file_writter.clear_log_files()
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

return setmetatable(M, {
	__call = function(self, name, force_logger_level_in_debug)
		return M.get_logger(name, force_logger_level_in_debug)
	end
})

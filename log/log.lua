local config = require("log.internal.config")
local formatter = require("log.internal.formatter")
local file_writer = require("log.internal.file_writer")

---@alias logger log

---@overload fun(name: string?, force_logger_level_in_debug: string?): logger
---@class log
---@field name string
---@field level string
---@field private _last_gc_memory number|nil
---@field private _last_message_time number|nil
local M = {}

local METATABLE = { __index = M }

-- User defined log handlers, see M.add_callback
local callbacks = {}


---Log message with specified level and message
---@private
---@param level string One of the next level: TRACE, DEBUG, INFO, WARN, ERROR
---@param message string? The log message. Nil only refreshes the tracking values
---@param context any Additional data to include with the log message.
function M:log(level, message, context)
	if config.LEVEL_PRIORITY[level] > config.LEVEL_PRIORITY[self.level] then
		return
	end

	if message then
		-- The caller is 3 levels up: user code -> logger:info -> logger:log
		local caller_info = debug.getinfo(3, "Sl")
		local log_message = formatter.format(self, level, message, context, caller_info)

		if config.IS_MOBILE then
			print(log_message)
		else
			io.stdout:write(log_message, "\n")
			io.stdout:flush()
		end

		file_writer.on_log(self, log_message)

		for index = 1, #callbacks do
			callbacks[index](self, level, message, context, log_message)
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


---Log message with TRACE level
---@param message string? Message to log. Nil only refreshes the memory/time tracking
---@param data any Additional context data
function M:trace(message, data)
	self:log(config.TRACE, message, data)
end


---Log message with DEBUG level
---@param message string? Message to log. Nil only refreshes the memory/time tracking
---@param data any Additional context data
function M:debug(message, data)
	self:log(config.DEBUG, message, data)
end


---Log message with INFO level
---@param message string? Message to log. Nil only refreshes the memory/time tracking
---@param data any Additional context data
function M:info(message, data)
	self:log(config.INFO, message, data)
end


---Log message with WARN level
---@param message string? Message to log. Nil only refreshes the memory/time tracking
---@param data any Additional context data
function M:warn(message, data)
	self:log(config.WARN, message, data)
end


---Log message with ERROR level
---@param message string? Message to log. Nil only refreshes the memory/time tracking
---@param data any Additional context data
function M:error(message, data)
	self:log(config.ERROR, message, data)
end


---Return the new logger instance
---@param logger_name string|nil Default is the file name of the current script
---@param force_logger_level_in_debug string|nil Debug builds only, values: FATAL, ERROR, WARN, INFO, DEBUG, TRACE
---@return logger
function M.get_logger(logger_name, force_logger_level_in_debug)
	local instance = {
		name = logger_name or formatter.get_default_logger_name(debug.getinfo(2, "S")),
		level = config.IS_DEBUG and force_logger_level_in_debug or config.GAME_LOG_LEVEL,
	}

	return setmetatable(instance, METATABLE)
end


---Add a custom handler for log messages
---@param callback fun(logger: logger, level: string, message: string, context: any, log_message: string)
function M.add_callback(callback)
	assert(type(callback) == "function", "Callback must be a function")
	table.insert(callbacks, callback)
end


---Remove a previously added handler
---@param callback function The callback function to remove
function M.remove_callback(callback)
	for index = 1, #callbacks do
		if callbacks[index] == callback then
			table.remove(callbacks, index)
			return
		end
	end
end


---Remove all custom handlers. The file writing is not affected
function M.clear_callbacks()
	callbacks = {}
end


---Set the log file for all loggers, in addition to the console and the personal logger files.
---The path is always relative: project folder in the editor, save folder on a device.
---The leading `/` is optional. Pass nil to disable
---@param path string|nil
---@return string|nil resolved_path
function M.set_file(path)
	return file_writer.set_file(path)
end


---Get the current log file path for all loggers, or nil if disabled
---@return string|nil
function M.get_file()
	return file_writer.get_file()
end


---Write this logger messages to a `<logger_name>.log` file next to the calling script.
---Editor and desktop builds only, since it requires the project folder
---@return string|nil resolved_path
function M:set_file_nearby()
	return file_writer.set_file_nearby(self, debug.getinfo(2, "S"))
end


---Delete all known logger .log files from the disk
function M.clear_log_files()
	file_writer.clear_log_files()
end


---Flush and close all opened log files.
---Call it once on the application shutdown, e.g. from the `final` of your bootstrap script
function M.final()
	file_writer.close_log_files()
end


-- The log module itself is a logger. Its name is resolved to the name
-- of the script that writes the message
M.name = config.AUTO_NAME
M.level = config.GAME_LOG_LEVEL

return setmetatable(M, {
	__call = function(_, name, force_logger_level_in_debug)
		name = name or formatter.get_default_logger_name(debug.getinfo(2, "S"))
		return M.get_logger(name, force_logger_level_in_debug)
	end
})

--- If native utf8 is available, use it, otherwise use string
local string_m = utf8 or string

---@alias logger log

---@class log
---@field name string
---@field level string
---@field private _last_gc_memory number
---@field private _last_message_time number
local M = {}

local IS_DEBUG = sys.get_engine_info().is_debug
local SYSTEM_NAME = sys.get_sys_info().system_name
local IS_MOBILE = SYSTEM_NAME == "iPhone OS" or SYSTEM_NAME == "Android"

local DEFAULT_LEVEL = IS_DEBUG and "TRACE" or "ERROR"
local GAME_LOG_LEVEL = sys.get_config_string(IS_DEBUG and "log.level" or "log.level_release", DEFAULT_LEVEL)

local LOGGER_BLOCK_WIDTH = sys.get_config_int("log.logger_block_width", 14)
local MAX_LOG_LENGTH = sys.get_config_int("log.max_log_length", 1024)
local INSPECT_DEPTH = sys.get_config_int("log.inspect_depth", 1)

local IS_TIME_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%time_tracking") ~= nil
local IS_MEMORY_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%memory_tracking") ~= nil
local IS_CHRONOS_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%chronos_tracking") ~= nil

-- Info: %levelname[%logger]
-- Message: %space%message: %context %tab<%function>
-- Preview: DEBUG:[game.logger     ]	Debug message: {debug: message, value: 2} 	<example/example.gui_script:17>

-- Info: %levelname| %time_tracking | %memory_tracking | %logger
-- Message: | %tab%message: %context %tab<%function>
-- Preview: DEBUG:| 166.71ms |   2.4kb | game.logger      |	Delayed message: just string 	<example/example.gui_script:39>

local INFO_BLOCK = sys.get_config_string("log.info_block", "%levelname[%logger]")
local IS_FORMAT_LOGGER = string_m.find(INFO_BLOCK, "%%logger") ~= nil
local IS_FORMAT_LEVEL_NAME = string_m.find(INFO_BLOCK, "%%levelname") ~= nil
local IS_FORMAT_LEVEL_SHORT = string_m.find(INFO_BLOCK, "%%levelshort") ~= nil

local MESSAGE_BLOCK = sys.get_config_string("log.message_block", "%space%message: %context %tab<%function>")
local IS_FORMAT_TAB = string_m.find(MESSAGE_BLOCK, "%%tab") ~= nil
local IS_FORMAT_SPACE = string_m.find(MESSAGE_BLOCK, "%%space") ~= nil
local IS_FORMAT_MESSAGE = string_m.find(MESSAGE_BLOCK, "%%message") ~= nil
local IS_FORMAT_CONTEXT = string_m.find(MESSAGE_BLOCK, "%%context") ~= nil
local IS_FORMAT_FUNCTION = string_m.find(MESSAGE_BLOCK, "%%function") ~= nil

local TRACE = "TRACE"
local DEBUG = "DEBUG"
local INFO = "INFO"
local WARN = "WARN"
local ERROR = "ERROR"
local FATAL = "FATAL"

local LEVEL_TO_CONSOLE_MAP = {
	[TRACE] = "TRACE:  ",
	[DEBUG] = "DEBUG:  ",
	[INFO]  = "INFO:   ",
	[WARN]  = "WARNING:",
	[ERROR] = "ERROR:  ",
	[FATAL] = "FATAL:  ",
}

local LEVEL_SHORT_TO_CONSOLE_MAP = {
	[TRACE] = "T",
	[DEBUG] = "D",
	[INFO]  = "I",
	[WARN]  = "W",
	[ERROR] = "E",
	[FATAL] = "F",
}

local LEVEL_PRIORITY = {
	[FATAL] = 0, -- Used to disable logs
	[ERROR] = 1,
	[WARN] = 2,
	[INFO] = 3,
	[DEBUG] = 4,
	[TRACE] = 5,
}

---Converts table to one-line string
---@param t table
---@param depth number
---@param result string|nil Internal parameter
---@return string, boolean result String representation of table, Is max string length reached
local function table_to_string(t, depth, result)
	if not t then
		return "", false
	end

	depth = depth or 0
	result = result or "{"

	if #result > MAX_LOG_LENGTH then
		return result:sub(1, MAX_LOG_LENGTH) .. " ...}", true
	end

	for key, value in pairs(t) do
		if #result > 1 then
			result = result .. ", "
		end

		if type(value) == "table" then
			if depth == 0 then
				local table_len = 0
				for _ in pairs(value) do
					table_len = table_len + 1
				end
				result = result .. key .. ": {... #" .. table_len .. "}"
			else
				local convert_result, is_limit = table_to_string(value, depth - 1, "")
				result = result .. key .. ": {" .. convert_result
				if is_limit then
					break
				end
			end
		else
			result = result .. key .. ": " .. tostring(value)
		end
	end

	if #result > MAX_LOG_LENGTH then
		return result:sub(1, MAX_LOG_LENGTH) .. " ...}", true
	end

	return result .. "}", false
end


---Format log message
---@local
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@return string|nil
function M:format(level, message, context)
	-- Format info block
	local string_info_block = INFO_BLOCK

	if IS_MEMORY_TRACK then
		local format = "%5.1fkb"
		local current_memory = collectgarbage("count")
		local diff_memory = current_memory - self._last_gc_memory

		if diff_memory < 0 then
			-- It's because of garbage collector
			format = "    ..."
		end

		if diff_memory > 1000 then
			diff_memory = diff_memory / 1000
			format = "%4.1f mb"
		end

		string_info_block = string_m.gsub(string_info_block, "%%memory_tracking", string.format(format, diff_memory))
	end

	if IS_TIME_TRACK then
		local format = "%6.2fms"
		local diff_time = (socket.gettime() - self._last_message_time) * 1000
		if diff_time > 1000 then
			diff_time = diff_time / 1000
			format = "%6.2f s"
		end

		string_info_block = string_m.gsub(string_info_block, "%%time_tracking", string.format(format, diff_time))
	end

	if IS_CHRONOS_TRACK then
		local format = "%8.4fms"
		local diff_time = (chronos.nanotime() - self._last_message_time) * 1000
		if diff_time > 1000 then
			diff_time = diff_time / 1000
			format = "%8.4f s"
		end

		string_info_block = string_m.gsub(string_info_block, "%%chronos_tracking", string.format(format, diff_time))
	end

	if IS_FORMAT_LOGGER then
		-- Make logger name length equal to LOGGER_BLOCK_WIDTH
		local name_to_insert = self.name
		local logger_name_length = string_m.len(self.name)
		if logger_name_length < LOGGER_BLOCK_WIDTH then
			name_to_insert = name_to_insert .. string.rep(" ", LOGGER_BLOCK_WIDTH - logger_name_length)
		elseif logger_name_length > LOGGER_BLOCK_WIDTH then
			name_to_insert = string_m.sub(name_to_insert, 1, LOGGER_BLOCK_WIDTH)
		end

		string_info_block = string_m.gsub(string_info_block, "%%logger", name_to_insert)
	end

	if IS_FORMAT_LEVEL_NAME then
		string_info_block = string_m.gsub(string_info_block, "%%levelname", LEVEL_TO_CONSOLE_MAP[level])
	end

	if IS_FORMAT_LEVEL_SHORT then
		string_info_block = string_m.gsub(string_info_block, "%%levelshort", string.sub(LEVEL_SHORT_TO_CONSOLE_MAP[level], 1, 5))
	end

	-- Format message block
	local string_message_block = MESSAGE_BLOCK
	if IS_FORMAT_TAB then
		string_message_block = string_m.gsub(string_message_block, "%%tab", "\t")
	end

	if IS_FORMAT_SPACE then
		string_message_block = string_m.gsub(string_message_block, "%%space", " ")
	end

	if IS_FORMAT_MESSAGE then
		string_message_block = string_m.gsub(string_message_block, "%%message", message)
	end

	if IS_FORMAT_CONTEXT then
		local record_context = ""
		if context ~= nil then
			local is_table = type(context) == "table"
			record_context = is_table and table_to_string(context, INSPECT_DEPTH) or tostring(context)
		end
		string_message_block = string_m.gsub(string_message_block, "%%context", record_context)
	end

	if IS_FORMAT_FUNCTION then
		local caller_info = debug.getinfo(4)
		string_message_block = string_m.gsub(string_message_block, "%%function", caller_info.short_src .. ":" .. caller_info.currentline)
	end

	return string_info_block .. string_message_block
end


---Log message with specified level and message
---@local
---@param level string One of the next level: TRACE, DEBUG, INFO, WARN, ERROR
---@param message string The log message.
---@param context any Additional data to include with the log message.
function M:log(level, message, context)
	if LEVEL_PRIORITY[level] > LEVEL_PRIORITY[self.level] then
		return nil
	end

	local log_message = self:format(level, message, context)

	if log_message then
		if IS_MOBILE then
			print(log_message)
		else
			io.stdout:write(log_message, "\n")
			io.stdout:flush()
		end
	end

	if IS_MEMORY_TRACK then
		self._last_gc_memory = collectgarbage("count")
	end

	if IS_TIME_TRACK then
		self._last_message_time = socket.gettime()
	end

	if IS_CHRONOS_TRACK then
		self._last_message_time = chronos.nanotime()
	end
end


---Log message with TRACE level
---@param message string Message to log
---@param data any
function M:trace(message, data)
	self:log(TRACE, message, data)
end


---Log message with DEBUG level
---@param message string Message to log
---@param data any
function M:debug(message, data)
	self:log(DEBUG, message, data)
end


---Log message with INFO level
---@param message string
---@param data any
function M:info(message, data)
	self:log(INFO, message, data)
end


---Log message with WARN level
---@param message string
---@param data any
function M:warn(message, data)
	self:log(WARN, message, data)
end


---Log message with ERROR level
---@param message string
---@param data any
function M:error(message, data)
	self:log(ERROR, message, data)
end


---Return the new logger instance
---@param logger_name string
---@param force_logger_level_in_debug string|nil Default is DEBUG, values: FATAL, ERROR, WARN, INFO, DEBUG, TRACE
---@return logger
function M.get_logger(logger_name, force_logger_level_in_debug)
	local instance = {
		name = logger_name or "",
		level = force_logger_level_in_debug or GAME_LOG_LEVEL,
	}

	if IS_MEMORY_TRACK then
		instance._last_gc_memory = collectgarbage("count")
	end

	if IS_TIME_TRACK then
		instance._last_message_time = socket.gettime()
	end

	if IS_CHRONOS_TRACK then
		instance._last_message_time = chronos.nanotime()
	end

	if not IS_DEBUG then
		if LEVEL_PRIORITY[instance.level] < LEVEL_PRIORITY[GAME_LOG_LEVEL] then
			instance.level = GAME_LOG_LEVEL
		end
	end

	return setmetatable(instance, { __index = M }) --[[@as logger]]
end


local PROJECT_TITLE = sys.get_config_string("project.title", "log")
local DEFAULT_LOGGER = M.get_logger(PROJECT_TITLE)
return setmetatable(M, {
	__index = DEFAULT_LOGGER,
})

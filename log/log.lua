--- If native utf8 is available, use it, otherwise use string
local string_m = utf8 or string

---@class log
local M = {}

local TYPE_TABLE = "table"
local IS_DEBUG = sys.get_engine_info().is_debug
local SYSTEM_NAME = sys.get_sys_info().system_name
local IS_MOBILE = SYSTEM_NAME == "iPhone OS" or SYSTEM_NAME == "Android"

local DEFAULT_LEVEL = IS_DEBUG and "DEBUG" or "WARN"
local GAME_LOG_LEVEL = sys.get_config_string(IS_DEBUG and "log.level" or "log.level_release", DEFAULT_LEVEL)

--local IS_TIME_TRACK = IS_DEBUG and sys.get_config_int("log.time_tracking", 0) == 1
--local IS_MEMORY_TRACK = IS_DEBUG and sys.get_config_int("log.memory_tracking", 0) == 1
local INFO_BLOCK_LENGTH = sys.get_config_int("log.info_block_length", 18)
local LOGGER_BLOCK_WIDTH = sys.get_config_int("log.logger_block_width", 10)
local MAX_LOG_LENGTH = sys.get_config_int("log.max_log_length", 1024)
local INSPECT_DEPTH = sys.get_config_int("log.inspect_depth", 1)

--%time_tracking %memory_tracking %chronos_tracking
-- Need to check if info block contains these flags
local IS_TIME_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%time_tracking") ~= nil
local IS_MEMORY_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%memory_tracking") ~= nil
local IS_CHRONOS_TRACK = IS_DEBUG and string_m.find(sys.get_config_string("log.info_block", ""), "%%chronos_tracking") ~= nil

local time_fn
local TIME_FORMAT
if IS_TIME_TRACK then
	--- If microsecond timer is available, use it, otherwise use built-in millisecond timer
	if chronos then
		time_fn = chronos.nanotime
		TIME_FORMAT = "%08.4fms"
	else
		time_fn = socket.gettime
		TIME_FORMAT = "%06.2fms"
	end
end


local INFO_BLOCK_DEFAULT = "%levelshort[%logger"
local MESSAGE_BLOCK_DEFAULT = "]: %message %context <%function>"

local INFO_BLOCK = sys.get_config_string("log.info_block", INFO_BLOCK_DEFAULT)
local MESSAGE_BLOCK = sys.get_config_string("log.message_block", MESSAGE_BLOCK_DEFAULT)

local IS_FORMAT_LOGGER = string_m.find(INFO_BLOCK, "%%logger") ~= nil
local IS_FORMAT_LEVEL_NAME = string_m.find(INFO_BLOCK, "%%levelname") ~= nil
local IS_FORMAT_LEVEL_SHORT = string_m.find(INFO_BLOCK, "%%levelshort") ~= nil

local IS_FORMAT_TAB = string_m.find(MESSAGE_BLOCK, "%%tab") ~= nil
local IS_FORMAT_MESSAGE = string_m.find(MESSAGE_BLOCK, "%%message") ~= nil
local IS_FORMAT_CONTEXT = string_m.find(MESSAGE_BLOCK, "%%context") ~= nil
local IS_FORMAT_FUNCTION = string_m.find(MESSAGE_BLOCK, "%%function") ~= nil

local TRACE = "TRACE"
local DEBUG = "DEBUG"
local INFO = "INFO"
local WARN = "WARN"
local ERROR = "ERROR"

local LEVEL_SHORT_NAME = {
	[TRACE] = "T",
	[DEBUG] = "D",
	[INFO] = "I",
	[WARN] = "W",
	[ERROR] = "ERROR:", -- Full name used for red highlight in Defold Editor console
}

local LEVEL_TO_CONSOLE_MAP = {
	[TRACE] = "TRACE:",
	[DEBUG] = "DEBUG:",
	[INFO] = "INFO: ",
	[WARN] = "WARN: ",
	[ERROR] = "ERROR:",
}

local LEVEL_PRIORITY = {
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

		if type(value) == TYPE_TABLE then
			if depth == 0 then
				result = result .. key .. ": {... #" .. #value .. "}"
			else
				local convert_result, is_limit = table_to_string(value, depth - 1, result .. key .. ": ")
				result = convert_result
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


---@class logger
---@field name string
---@field level string
---@field private _last_gc_memory number
---@field private _last_message_time number
local Logger = {}

---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@return string|nil
function Logger:format(level, message, context)
	-- Format info block
	local string_info_block = INFO_BLOCK

	local current_time = IS_TIME_TRACK and time_fn()
	if IS_MEMORY_TRACK then
		local current_memory = collectgarbage("count")
		local diff_memory = math.max(current_memory - self._last_gc_memory, 0)

		string_info_block = string_m.gsub(string_info_block, "%%memory_tracking", string.format("%04.1fkb", diff_memory))
	end
	if IS_TIME_TRACK then
		-- Debug time tracking (in ms)
		local diff_time = (current_time - self._last_message_time) * 1000

		string_info_block = string_m.gsub(string_info_block, "%%time_tracking", string.format(TIME_FORMAT, diff_time))
	end
	if IS_FORMAT_LOGGER then
		--string_info_block = string_m.gsub(string_info_block, "%%logger", self.name)

		-- Make logger name length equal to LOGGER_BLOCK_WIDTH
		local name_to_instert = self.name
		local logger_name_length = string_m.len(name_to_instert)
		if logger_name_length < LOGGER_BLOCK_WIDTH then
			name_to_instert = name_to_instert .. string.rep(" ", LOGGER_BLOCK_WIDTH - logger_name_length)
		elseif logger_name_length > LOGGER_BLOCK_WIDTH then
			name_to_instert = string_m.sub(name_to_instert, 1, LOGGER_BLOCK_WIDTH)
		end

		string_info_block = string_m.gsub(string_info_block, "%%logger", name_to_instert)
	end
	if IS_FORMAT_LEVEL_SHORT then
		string_info_block = string_m.gsub(string_info_block, "%%levelshort", LEVEL_SHORT_NAME[level])
	end
	if IS_FORMAT_LEVEL_NAME then
		string_info_block = string_m.gsub(string_info_block, "%%levelname", LEVEL_TO_CONSOLE_MAP[level])
	end

	-- Format message block
	local string_message_block = MESSAGE_BLOCK
	if IS_FORMAT_TAB then
		string_message_block = string_m.gsub(string_message_block, "%%tab", "\t")
	end
	if IS_FORMAT_MESSAGE then
		string_message_block = string_m.gsub(string_message_block, "%%message", message)
	end
	if IS_FORMAT_CONTEXT then
		local record_context = ""
		if context ~= nil then
			local is_table = type(context) == TYPE_TABLE
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


---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
function Logger:log(level, message, context)
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
		self._last_message_time = time_fn()
	end
end


---Log message with TRACE level
---@param message string Message to log
---@param data any
function Logger:trace(message, data)
	self:log(TRACE, message, data)
end


---Log message with DEBUG level
---@param message string Message to log
---@param data any
function Logger:debug(message, data)
	self:log(DEBUG, message, data)
end


---Log message with INFO level
---@param message string
---@param data any
function Logger:info(message, data)
	self:log(INFO, message, data)
end


---Log message with WARN level
---@param message string
---@param data any
function Logger:warn(message, data)
	self:log(WARN, message, data)
end


---Log message with ERROR level
---@param message string
---@param data any
function Logger:error(message, data)
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
		instance._last_message_time = time_fn()
	end

	if not IS_DEBUG then
		if LEVEL_PRIORITY[instance.level] < LEVEL_PRIORITY[GAME_LOG_LEVEL] then
			instance.level = GAME_LOG_LEVEL
		end
	end

	return setmetatable(instance, { __index = Logger })
end


local DEFAULT_LOGGER = M.get_logger(sys.get_config_string("project.title", "log"))
return setmetatable(M, {
	__index = DEFAULT_LOGGER,
})

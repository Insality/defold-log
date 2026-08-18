--- If native utf8 is available, use it, otherwise use string
local string_m = utf8 or string

local config = require("log.internal.config")

local M = {}

-- Cache for source to name mapping
local SOURCE_TO_NAME_MAP = {}

-- Used when the caller can not be resolved from the stack
local UNKNOWN_CALLER = { short_src = "?", currentline = 0 }

-- Placeholder name -> value, reused between the calls
local INFO_VALUES = {}
local MESSAGE_VALUES = {}

local PLACEHOLDER_PATTERN = "%%([%w_]+)"


---Cut the result to the max log length and mark it as truncated
---@param result string
---@return string, boolean
local function truncated(result)
	return result:sub(1, config.MAX_LOG_LENGTH) .. " ...}", true
end


---Pick the millisecond or the second format, whichever fits the value better
---@param diff_ms number
---@param ms_format string
---@param s_format string
---@return string
local function format_elapsed(diff_ms, ms_format, s_format)
	if diff_ms > 1000 then
		return string.format(s_format, diff_ms / 1000)
	end

	return string.format(ms_format, diff_ms)
end


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

	if #result > config.MAX_LOG_LENGTH then
		return truncated(result)
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
					return truncated(result)
				end
			end
		else
			result = result .. key .. ": " .. tostring(value)
		end

		if #result > config.MAX_LOG_LENGTH then
			return truncated(result)
		end
	end

	return result .. "}", false
end


---Return the basename of the script from the debug info
---@param debuginfo debuginfo|nil
---@return string
function M.get_default_logger_name(debuginfo)
	local script_path = debuginfo and debuginfo.short_src or UNKNOWN_CALLER.short_src

	local name = SOURCE_TO_NAME_MAP[script_path]
	if not name then
		name = string.match(script_path, "([^/\\]+)$") or script_path
		name = string.match(name, "(.*)%..*$") or name
		SOURCE_TO_NAME_MAP[script_path] = name
	end

	return name
end


---Pad or cut the logger name to LOGGER_BLOCK_WIDTH, so the blocks stay aligned
---@param name string
---@return string
local function fit_logger_name(name)
	local length = string_m.len(name)

	if length < config.LOGGER_BLOCK_WIDTH then
		return name .. string.rep(" ", config.LOGGER_BLOCK_WIDTH - length)
	end

	if length > config.LOGGER_BLOCK_WIDTH then
		return string_m.sub(name, 1, config.LOGGER_BLOCK_WIDTH)
	end

	return name
end


---@param logger logger Logger instance
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param caller_info debuginfo Caller debug info
local function fill_info_values(logger, level, caller_info)
	if config.IS_MEMORY_TRACK then
		local current_memory = collectgarbage("count")
		logger._last_gc_memory = logger._last_gc_memory or current_memory
		local diff_memory = current_memory - logger._last_gc_memory

		local format = "%5.1fkb"
		if diff_memory < 0 then
			-- It's because of garbage collector
			format = "    ..."
		elseif diff_memory > 1000 then
			diff_memory = diff_memory / 1000
			format = "%4.1f mb"
		end

		INFO_VALUES.memory_tracking = string.format(format, diff_memory)
	end

	if config.IS_TIME_TRACK then
		logger._last_message_time = logger._last_message_time or socket.gettime()
		local diff_time = (socket.gettime() - logger._last_message_time) * 1000
		INFO_VALUES.time_tracking = format_elapsed(diff_time, "%6.2fms", "%6.2f s")
	end

	if config.IS_CHRONOS_TRACK then
		logger._last_message_time = logger._last_message_time or chronos.nanotime()
		local diff_time = (chronos.nanotime() - logger._last_message_time) * 1000
		INFO_VALUES.chronos_tracking = format_elapsed(diff_time, "%8.4fms", "%8.4f s")
	end

	if config.IS_FORMAT_LOGGER then
		local name = logger.name
		if name == config.AUTO_NAME then
			name = M.get_default_logger_name(caller_info)
		end

		INFO_VALUES.logger = fit_logger_name(name)
	end

	if config.IS_FORMAT_LEVEL_NAME then
		INFO_VALUES.levelname = config.LEVEL_TO_CONSOLE_MAP[level]
	end

	if config.IS_FORMAT_LEVEL_SHORT then
		INFO_VALUES.levelshort = config.LEVEL_SHORT_TO_CONSOLE_MAP[level]
	end
end


---@param message string Message to log
---@param context any Additional data to log
---@param caller_info debuginfo Caller debug info
local function fill_message_values(message, context, caller_info)
	if config.IS_FORMAT_TAB then
		MESSAGE_VALUES.tab = "\t"
	end

	if config.IS_FORMAT_SPACE then
		MESSAGE_VALUES.space = " "
	end

	if config.IS_FORMAT_MESSAGE then
		MESSAGE_VALUES.message = message
	end

	if config.IS_FORMAT_CONTEXT then
		local record_context = ""
		if context ~= nil then
			local is_table = type(context) == "table"
			record_context = is_table and table_to_string(context, config.INSPECT_DEPTH) or tostring(context)
		end

		MESSAGE_VALUES.context = record_context
	end

	if config.IS_FORMAT_FUNCTION then
		MESSAGE_VALUES["function"] = caller_info.short_src .. ":" .. caller_info.currentline
	end
end


---Format log message
---@param logger logger Logger instance
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@param caller_info debuginfo|nil Caller debug info from the public log method
---@return string
function M.format(logger, level, message, context, caller_info)
	caller_info = caller_info or UNKNOWN_CALLER

	fill_info_values(logger, level, caller_info)
	fill_message_values(message, context, caller_info)

	local info_block = string.gsub(config.INFO_BLOCK, PLACEHOLDER_PATTERN, INFO_VALUES)
	local message_block = string.gsub(config.MESSAGE_BLOCK, PLACEHOLDER_PATTERN, MESSAGE_VALUES)

	return info_block .. message_block
end


return M

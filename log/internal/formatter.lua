--- If native utf8 is available, use it, otherwise use string
local string_m = utf8 or string

local config = require("log.internal.config")

local M = {}

-- Cache for source to name mapping
local SOURCE_TO_NAME_MAP = {}

-- Used when the caller can not be resolved from the stack
local UNKNOWN_CALLER = { short_src = "?", currentline = 0 }


---A gsub replacement string treats `%` as an escape character, so every value
---taken from the game itself has to be escaped before it is inserted
---@param text string
---@return string
local function escape(text)
	if string.find(text, "%", 1, true) then
		return (string.gsub(text, "%%", "%%%%"))
	end

	return text
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
		return result:sub(1, config.MAX_LOG_LENGTH) .. " ...}", true
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

	if #result > config.MAX_LOG_LENGTH then
		return result:sub(1, config.MAX_LOG_LENGTH) .. " ...}", true
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


---Format log message
---@param logger logger Logger instance
---@param level string TRACE, DEBUG, INFO, WARN, ERROR
---@param message string Message to log
---@param context any Additional data to log
---@param caller_info debuginfo|nil Caller debug info from the public log method
---@return string
function M.format(logger, level, message, context, caller_info)
	caller_info = caller_info or UNKNOWN_CALLER

	-- Format info block
	local string_info_block = config.INFO_BLOCK

	if config.IS_MEMORY_TRACK then
		local format = "%5.1fkb"
		local current_memory = collectgarbage("count")
		logger._last_gc_memory = logger._last_gc_memory or current_memory
		local diff_memory = current_memory - logger._last_gc_memory

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

	if config.IS_TIME_TRACK then
		local format = "%6.2fms"
		logger._last_message_time = logger._last_message_time or socket.gettime()
		local diff_time = (socket.gettime() - logger._last_message_time) * 1000
		if diff_time > 1000 then
			diff_time = diff_time / 1000
			format = "%6.2f s"
		end

		string_info_block = string_m.gsub(string_info_block, "%%time_tracking", string.format(format, diff_time))
	end

	if config.IS_CHRONOS_TRACK then
		local format = "%8.4fms"
		logger._last_message_time = logger._last_message_time or chronos.nanotime()
		local diff_time = (chronos.nanotime() - logger._last_message_time) * 1000
		if diff_time > 1000 then
			diff_time = diff_time / 1000
			format = "%8.4f s"
		end

		string_info_block = string_m.gsub(string_info_block, "%%chronos_tracking", string.format(format, diff_time))
	end

	if config.IS_FORMAT_LOGGER then
		-- Make logger name length equal to LOGGER_BLOCK_WIDTH
		local name_to_insert = logger.name

		if name_to_insert == config.AUTO_NAME then
			name_to_insert = M.get_default_logger_name(caller_info)
		end

		local logger_name_length = string_m.len(name_to_insert)
		if logger_name_length < config.LOGGER_BLOCK_WIDTH then
			name_to_insert = name_to_insert .. string.rep(" ", config.LOGGER_BLOCK_WIDTH - logger_name_length)
		elseif logger_name_length > config.LOGGER_BLOCK_WIDTH then
			name_to_insert = string_m.sub(name_to_insert, 1, config.LOGGER_BLOCK_WIDTH)
		end

		string_info_block = string_m.gsub(string_info_block, "%%logger", escape(name_to_insert))
	end

	if config.IS_FORMAT_LEVEL_NAME then
		string_info_block = string_m.gsub(string_info_block, "%%levelname", config.LEVEL_TO_CONSOLE_MAP[level])
	end

	if config.IS_FORMAT_LEVEL_SHORT then
		string_info_block = string_m.gsub(string_info_block, "%%levelshort", config.LEVEL_SHORT_TO_CONSOLE_MAP[level])
	end

	-- Format message block
	local string_message_block = config.MESSAGE_BLOCK
	if config.IS_FORMAT_TAB then
		string_message_block = string_m.gsub(string_message_block, "%%tab", "\t")
	end

	if config.IS_FORMAT_SPACE then
		string_message_block = string_m.gsub(string_message_block, "%%space", " ")
	end

	if config.IS_FORMAT_MESSAGE then
		string_message_block = string_m.gsub(string_message_block, "%%message", escape(message))
	end

	if config.IS_FORMAT_CONTEXT then
		local record_context = ""
		if context ~= nil then
			local is_table = type(context) == "table"
			record_context = is_table and table_to_string(context, config.INSPECT_DEPTH) or tostring(context)
		end
		string_message_block = string_m.gsub(string_message_block, "%%context", escape(record_context))
	end

	if config.IS_FORMAT_FUNCTION then
		local caller = caller_info.short_src .. ":" .. caller_info.currentline
		string_message_block = string_m.gsub(string_message_block, "%%function", escape(caller))
	end

	return string_info_block .. string_message_block
end


return M

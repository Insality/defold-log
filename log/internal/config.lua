local M = {}

-- Log levels
M.TRACE = "TRACE"
M.DEBUG = "DEBUG"
M.INFO = "INFO"
M.WARN = "WARN"
M.ERROR = "ERROR"
M.FATAL = "FATAL"

M.LEVEL_TO_CONSOLE_MAP = {
	[M.TRACE] = "TRACE:  ",
	[M.DEBUG] = "DEBUG:  ",
	[M.INFO]  = "INFO:   ",
	[M.WARN]  = "WARNING:",
	[M.ERROR] = "ERROR:  ",
	[M.FATAL] = "FATAL:  ",
}

M.LEVEL_SHORT_TO_CONSOLE_MAP = {
	[M.TRACE] = "T",
	[M.DEBUG] = "D",
	[M.INFO]  = "I",
	[M.WARN]  = "W",
	[M.ERROR] = "E",
	[M.FATAL] = "F",
}

M.LEVEL_PRIORITY = {
	[M.FATAL] = 0, -- Used to disable logs
	[M.ERROR] = 1,
	[M.WARN] = 2,
	[M.INFO] = 3,
	[M.DEBUG] = 4,
	[M.TRACE] = 5,
}

-- Logger name that is resolved to the calling script name on every message
M.AUTO_NAME = "log_auto_name"

M.APP_NAME = sys.get_config_string("project.title", "defold-log")
M.STATE_PATH = sys.get_save_file(M.APP_NAME, "log_state")

M.IS_DEBUG = sys.get_engine_info().is_debug
M.SYSTEM_NAME = sys.get_sys_info().system_name
M.IS_MOBILE = M.SYSTEM_NAME == "iPhone OS" or M.SYSTEM_NAME == "Android"
M.IS_HTML5 = M.SYSTEM_NAME == "HTML5"
M.CAN_MKDIR = not M.IS_MOBILE and not M.IS_HTML5 and os.execute ~= nil

M.GAME_LOG_LEVEL = M.IS_DEBUG
	and sys.get_config_string("log.level", M.TRACE)
	or sys.get_config_string("log.level_release", M.ERROR)

if not M.LEVEL_PRIORITY[M.GAME_LOG_LEVEL] then
	print("log: unknown log level in game.project, the default one is used: " .. tostring(M.GAME_LOG_LEVEL))
	M.GAME_LOG_LEVEL = M.IS_DEBUG and M.TRACE or M.ERROR
end

M.LOGGER_BLOCK_WIDTH = sys.get_config_int("log.logger_block_width", 14)
M.MAX_LOG_LENGTH = sys.get_config_int("log.max_log_length", 1024)
M.INSPECT_DEPTH = sys.get_config_int("log.inspect_depth", 2)

-- Optional log file for all loggers, see file_writer.lua
M.LOG_FILE = sys.get_config_string("log.file", "")

-- Debug and release builds use separate format settings, so the tracking
-- placeholders never end up in a release build where tracking is not wanted
M.INFO_BLOCK = M.IS_DEBUG
	and sys.get_config_string("log.info_block", "%levelname| %time_tracking | %memory_tracking | %logger")
	or sys.get_config_string("log.info_block_release", "%levelname| %logger")
M.MESSAGE_BLOCK = sys.get_config_string("log.message_block", "| %tab%message: %context %tab<%function>")

-- A placeholder in the format block enables the matching feature.
-- Plain text search, so `%` needs no escaping and can not be read as a pattern class
local function has_placeholder(block, placeholder)
	return string.find(block, placeholder, 1, true) ~= nil
end

M.IS_TIME_TRACK = has_placeholder(M.INFO_BLOCK, "%time_tracking")
M.IS_MEMORY_TRACK = has_placeholder(M.INFO_BLOCK, "%memory_tracking")
M.IS_CHRONOS_TRACK = has_placeholder(M.INFO_BLOCK, "%chronos_tracking")

M.IS_FORMAT_LOGGER = has_placeholder(M.INFO_BLOCK, "%logger")
M.IS_FORMAT_LEVEL_NAME = has_placeholder(M.INFO_BLOCK, "%levelname")
M.IS_FORMAT_LEVEL_SHORT = has_placeholder(M.INFO_BLOCK, "%levelshort")
M.IS_FORMAT_TAB = has_placeholder(M.MESSAGE_BLOCK, "%tab")
M.IS_FORMAT_SPACE = has_placeholder(M.MESSAGE_BLOCK, "%space")
M.IS_FORMAT_MESSAGE = has_placeholder(M.MESSAGE_BLOCK, "%message")
M.IS_FORMAT_CONTEXT = has_placeholder(M.MESSAGE_BLOCK, "%context")
M.IS_FORMAT_FUNCTION = has_placeholder(M.MESSAGE_BLOCK, "%function")

if M.IS_CHRONOS_TRACK and not chronos then
	print("log: %chronos_tracking needs the defold-chronos extension, it is ignored")
	M.IS_CHRONOS_TRACK = false
	-- Drop the placeholder too, so it does not stay in the output as a literal
	M.INFO_BLOCK = string.gsub(M.INFO_BLOCK, "%%chronos_tracking", "")
end


return M

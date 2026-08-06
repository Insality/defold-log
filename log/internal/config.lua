--- If native utf8 is available, use it, otherwise use string
local string_m = utf8 or string

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

M.GAME_LOG_LEVEL = M.IS_DEBUG
	and sys.get_config_string("log.level", M.TRACE)
	or sys.get_config_string("log.level_release", M.ERROR)

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

-- A placeholder in the format block enables the matching feature
M.IS_TIME_TRACK = string_m.find(M.INFO_BLOCK, "%%time_tracking") ~= nil
M.IS_MEMORY_TRACK = string_m.find(M.INFO_BLOCK, "%%memory_tracking") ~= nil
M.IS_CHRONOS_TRACK = string_m.find(M.INFO_BLOCK, "%%chronos_tracking") ~= nil

M.IS_FORMAT_LOGGER = string_m.find(M.INFO_BLOCK, "%%logger") ~= nil
M.IS_FORMAT_LEVEL_NAME = string_m.find(M.INFO_BLOCK, "%%levelname") ~= nil
M.IS_FORMAT_LEVEL_SHORT = string_m.find(M.INFO_BLOCK, "%%levelshort") ~= nil
M.IS_FORMAT_TAB = string_m.find(M.MESSAGE_BLOCK, "%%tab") ~= nil
M.IS_FORMAT_SPACE = string_m.find(M.MESSAGE_BLOCK, "%%space") ~= nil
M.IS_FORMAT_MESSAGE = string_m.find(M.MESSAGE_BLOCK, "%%message") ~= nil
M.IS_FORMAT_CONTEXT = string_m.find(M.MESSAGE_BLOCK, "%%context") ~= nil
M.IS_FORMAT_FUNCTION = string_m.find(M.MESSAGE_BLOCK, "%%function") ~= nil


return M

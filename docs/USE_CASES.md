# Use Cases for the Log Module in Defold

This document provides practical examples of how to utilize the Log module in various scenarios to enhance your development workflow in Defold.

## 1. Memory and Time Profiling for Functions

Memory and time profiling are essential for optimizing the performance of your game. The Log module allows you to easily track how much memory and time your functions are using.

```lua
local log = require("log.log")
local logger = log.get_logger("game")

function init(self)
    logger:trace("Before expensive operation")

    expensive_operation()
    logger:trace("After expensive operation")
end
```

Output

```lua
TRACE:|   0.00ms |   0.0kb | game.logger     | 	Before expensive operation:  	<example/example.gui_script:62>
TRACE:|   1.71ms |   7.2kb | game.logger     | 	After expensive operation:  	<example/example.gui_script:64>
```

In this example, the `expensive_operation` function is profiled to measure the time and memory usage. This information can help you identify bottlenecks and optimize your game's performance.


## 2. Profile Module with Force Debug Level

Forcing a trace/debug level can be useful for detailed debugging of specific modules without changing the global log level. This approach helps in focusing on the relevant log messages during development.

```lua
local log = require("log.log")
local logger = log.get_logger("module.awesome", "TRACE")

function awesome_function()
    logger:trace("awesome_function")
    ...
    logger:debug("Some debug information", { data = data })
end

function init(self)
    awesome_function()
end
```

Here, the logger is forced to log at the trace level, while the rest of the application continues to log at the default level. This allows you to focus on the specific module's log messages without affecting the global log level.


## 3. Filter Logs in Defold Console

Defold's console allows filtering logs by level or logger name, enabling you to focus on the most relevant information. You can use the Log module's structured logging format to simplify this process.

For example, your can set up filters with "TRACE" to show only trace logs, "DEBUG" to show only debug logs, and so on. or "[game" to show only logs from the "game" logger.

![](media/filter_logs.png)


## 4. Integrating the Log Module into Your Library

To set ability to use custom logger in your library, you can use the following approach:

```lua
-- The trick with empty function saves a bit of memory
local EMPTY_FUNCTION = function() end

-- Create a logger object with functions for each log level
local logger = {
    trace = EMPTY_FUNCTION,
    debug = EMPTY_FUNCTION,
    info = EMPTY_FUNCTION,
    warn = EMPTY_FUNCTION,
    error = EMPTY_FUNCTION,
}

-- Add function to set the logger instance
function M.set_logger(logger_instance)
    M.logger = logger_instance
end
```

### Usage:

After setting an stub logger, you can use it in your library:

```lua
logger:warn("Something happened here:", {
    animation_path = animation_path,
    node_id = node_id
})
```

This allow to users of your library to set their logger instance and catch logs from your library.


## 6. Using log module as a logger itself

```lua
local log = require("log.log")

--- You can invoke a log module itself to write log message
--- The logger name will be equals to project.title field from game.project
--- But general practice is to create specific logger for each module
log:trace("message", { foo = bar })
log:debug("message", { foo = bar })
log:info("message", { foo = bar })
log:warn("message", { foo = bar })
log:error("message", { foo = bar })
```
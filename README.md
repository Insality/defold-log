![](media/logo.png)

[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/insality) [![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/insality) [![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/insality)

[![GitHub release (latest by date)](https://img.shields.io/github/v/tag/insality/defold-log?style=for-the-badge&label=Release)](https://github.com/Insality/defold-log/tags)

# Log

**Log** - is a single file Lua library for [Defold](https://defold.com/) game engine, enabling efficient logging for game development. It simplifies debugging and monitoring by allowing developers to generate detailed logs that can be adjusted for different stages of development.

## Features

- **Log Levels**: Includes TRACE, DEBUG, INFO, WARN, and ERROR for varied detail in logging.
- **Build-specific Logging**: Allows changing log verbosity between debug and release builds.
- **Detailed Context**: Supports logging with additional information for context, such as variable values or state information.
- **Format Customization**: Allows customizing the log message format.
- **Performance Tracking**: Provides features to log execution time and memory use.

## Setup

### [Dependency](https://www.defold.com/manuals/libraries/)

Open your `game.project` file and add the following line to the dependencies field under the project section:

**[Log v3](https://github.com/Insality/defold-log/archive/refs/tags/3.zip)**

```
https://github.com/Insality/defold-log/archive/refs/tags/3.zip
```

### Library Size

> **Note:** The library size is calculated based on the build report per platform

| Platform         | Library Size |
| ---------------- | ------------ |
| HTML5            | **2.54 KB**  |
| Desktop / Mobile | **4.28 KB**  |

### Configuration

You have the option to configure logging preferences directly within your `game.project` file. This allows you to adjust log levels, format, and performance tracking options.

This is a default configuration for the Log module:

```ini
[log]
level = DEBUG
level_release = WARN
time_tracking = 0
memory_tracking = 0
info_block_length = 18
info_block = %levelshort[%logger
message_block = ]: %message %context %tab<%function>
max_log_length = 512
inspect_depth = 1
```

This configuration section for `game.project` defines various settings:

- **level**: Sets the default logging level for development builds. In this case, `DEBUG` level logs will be shown, including more detailed information useful during development.
- **level_release**: Determines the logging level for release builds, where `WARN` and above levels will be logged, focusing on warnings and errors that are critical for a production environment.
- **memory_tracking**: Enables (`1`) or disables (`0`) memory tracking, allowing logs to include information about memory allocations which can be useful for identifying memory leaks or unexpected memory usage. Works only in debug mode.
- **time_tracking**: Enables (`1`) or disables (`0`) time tracking, which adds execution time information to the logs, useful for performance analysis and identifying slow operations. Works only in debug mode.
- **info_block_length**: Specifies the fixed length for the info block portion of the log message, ensuring a uniform appearance in log outputs.
- **info_block**: Defines the format of the info block in log messages, which includes the log level and logger name in this configuration.
- **message_block**: Sets the format for the message block, including the actual log message, any context provided, and the function from which the log was called.
- **max_log_length**: The maximum length of the log message. If the message exceeds this length, it will be truncated. Default is 512.
- **inspect_depth**: The maximum depth of nested tables to inspect when logging. Default is 1.

In the `[log]` configuration section for `game.project`, the `info_block` and `message_block` fields allow for dynamic content based on specific placeholders. These placeholders get replaced with actual log information at runtime, providing structured and informative log messages.

#### Info Block Placeholders:
- **%logger**: The name of the logger instance producing the log message. Helps in identifying the source of the log message.
- **%levelname**: The full name of the log level (e.g., DEBUG, INFO, WARN, etc.). Provides clarity on the severity or nature of the log message.
- **%levelshort**: A shortened representation of the log level (e.g., D for DEBUG, I for INFO, W for WARN, etc.). Offers a concise way to present the log level, saving space in log messages.

#### Message Block Placeholders:
- **%tab**: A tab character for formatting log messages.
- **%message**: The actual log message content. This is the primary information you want to log.
- **%context**: Any additional context provided along with the log message. It can be useful for providing extra information relevant to the log message (e.g., variable values, state information).
- **%function**: The function name or location from where the log message was generated. Helps in pinpointing where in the codebase a particular log message is coming from, aiding in debugging.


### Memory Tracking

With `memory_tracking` enabled in `game.project`, log messages prepend memory usage, showing allocations since the last entry in this logger instance, e.g., `0.12kb [game.logger]: My log message`. Without this, logs exclude memory data for simpler output.

Works only in debug mode, automatically disabled in release mode.


### Time Tracking

When `time_tracking` is active, logs start with a timestamp in milliseconds to indicate the time elapsed since the last entry in this logger instance, like `0.01ms [game.logger]: Event triggered`. Disabling it removes this timing information.

Works only in debug mode, automatically disabled in release mode.


### Using Native UTF8 Extension

The Log module can utilize the native UTF8 extension for Defold to handle UTF-8 strings. This is optional but recommended for better performance.

If you want to use the native UTF8 extension, add the following line to the dependencies field in your `game.project` file:

**[defold-utf8](https://github.com/d954mas/defold-utf8)**
```
https://github.com/d954mas/defold-utf8/archive/master.zip
```

The Log module automatically detects the presence of the native UTF8 extension and uses it if available. If the extension is not present, the Log module will use the built-in string functions.


### Using High Resolution Timer Extension

The Log module can utilize the Chronos extension for Defold to enable time tracking with microsecond or better precision (`QueryPerformanceCounter` on Windows). This is optional.

If you want to use the extension, add the following line to the dependencies field in your `game.project` file:

**[defold-chronos](https://github.com/d954mas/defold-chronos)**
```
https://github.com/d954mas/defold-chronos/archive/refs/tags/1.0.1.zip
```

The Log module automatically detects the presence of the extension and uses it if available. If the extension is not present, the Log module will use the built-in `socket.gettime` function.


## API Documentation

### Quick API Reference

```lua
log.get_logger(logger_name, [force_logger_level_in_debug])
logger:trace(message, [data])
logger:debug(message, [data])
logger:info(message, [data])
logger:warn(message, [data])
logger:error(message, [data])
```

### Setup and Initialization

To start using the Log module in your project, you first need to import it. This can be done with the following line of code:

```lua
local log = require("log.log")
```

### Core Functions

**log.get_logger**
---
```lua
log.get_logger(logger_name, [force_logger_level_in_debug])
```
Create a new logger instance with an optional forced log level for debugging purposes.

- **Parameters:**
  - `logger_name`: A string representing the name of the logger.
  - `force_logger_level_in_debug` (optional): A string representing the forced log level when in debug mode (e.g., "DEBUG", "INFO").

- **Return Value:** A new logger instance.

- **Usage Example:**

```lua
local my_logger = log.get_logger("game.logger")
```

### Logger Instance Methods

Once a logger instance is created, you can use the following methods to log messages at different levels. Each logging method allows including optional data for context, which can be especially useful for debugging. However, note that passing data can lead to additional memory allocation, which might impact performance.

**logger:trace**
---
```lua
logger:trace(message, [data])
```
Log a message at the TRACE level. Trace is typically used to log the start and end of functions or specific events. While it's not recommended to pass data to trace due to potential memory allocation, sometimes it can be useful for in-depth debugging.

- **Parameters:**
  - `message`: The log message.
  - `data` (optional): Additional data to include with the log message.

- **Usage Example:**

```lua
my_logger:trace("Trace message")

-- 0.01ms 0.11kb T[game.logger]: Trace message <example/example.gui_script:33>
```

**logger:debug**
---
```lua
logger:debug(message, [data])
```
Log a message at the DEBUG level. Debug is suitable for detailed system information that could be helpful during development to track down unexpected behavior.

- **Usage Example:**

```lua
my_logger:debug("Debug message", { key = "value" })

-- 0.01ms 0.11kb D[game.logger]: Debug message {key: value} <example/example.gui_script:34>
```

**logger:info**
---
```lua
logger:info(message, [data])
```
Log a message at the INFO level. Info is used for general system information under normal operation.

- **Usage Example:**

```lua
my_logger:info("Info message", { key = "value" })

-- 0.01ms 0.11kb I[game.logger]: Info message {key: value} <example/example.gui_script:35>
```

**logger:warn**
---
```lua
logger:warn(message, [data])
```
Log a message at the WARN level. Warn is intended for potentially harmful situations that could require attention.

- **Usage Example:**

```lua
my_logger:warn("Warn message", { key = "value" })

-- 0.01ms 0.11kb W[game.logger]: Warn message {key: value} <example/example.gui_script:36>
```

**logger:error**
---
```lua
logger:error(message, [data])
```
Log a message at the ERROR level. Error indicates serious issues that have occurred and should be addressed immediately.

- **Usage Example:**

```lua
my_logger:error("Error message", {error = "file not found"})

-- Error output starts from ERROR: to highlight the line in the Defold Console
-- ERROR:[game.logger         ]: Error message {error: file not found} <example/example.gui_script:37>
```

These methods provide a comprehensive logging solution, allowing you to capture detailed information about your application's behavior, performance, and issues across different stages of development.


## Usage Examples

### Basic Logging

```lua
local log = require("log.log")

-- Create logger instances for different components of your game
local logger = log.get_logger("game.logger")

function init(self)
    logger:trace("init")
    logger:debug("Debugging game start", { level = 1, start = true })
    logger:info("Game level loaded")
    logger:warn("Unexpected behavior detected", { warning = "minor" })
    logger:error("Critical error encountered", { error = "out of memory" })
end

```

### Use Cases

Read the [Use Cases](USE_CASES.md) file for detailed examples of how to use the Log module in different scenarios.


## License

This project is licensed under the MIT License - see the LICENSE file for details.


## Issues and Suggestions

For any issues, questions, or suggestions, please [create an issue](https://github.com/Insality/defold-log/issues).

To contribute, please look for issues tagged with `[Contribute]`, solve them, and submit a PR focusing on performance and code style for efficient and maintainable enhancements. Your contributions are greatly appreciated!


## 👏 Contributors

<a href="https://github.com/Insality/defold-log/graphs/contributors">
  <img src="https://contributors-img.web.app/image?repo=insality/defold-log"/>
</a>


## Changelog

### **V1**
<details>
	<summary><b>Changelog</b></summary>

	- Initial release
</details>

### **V2**
<details>
	<summary><b>Changelog</b></summary>

	- Add chronos extension support
</details>


### **V3**
<details>
	<summary><b>Changelog</b></summary>

	- [#1] Add inspect_depth settings to game.project
	- [#2] Add max_log_length settings to game.project
</details>


## ❤️ Support the Project ❤️

Your support motivates me to keep creating and maintaining projects for **Defold**. Consider supporting if you find my projects helpful and valuable.

[![Github-sponsors](https://img.shields.io/badge/sponsor-30363D?style=for-the-badge&logo=GitHub-Sponsors&logoColor=#EA4AAA)](https://github.com/sponsors/insality) [![Ko-Fi](https://img.shields.io/badge/Ko--fi-F16061?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/insality) [![BuyMeACoffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/insality)


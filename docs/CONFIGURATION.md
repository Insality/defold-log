# Configuration

## Configuration [Optional]

You have the option to configure logging preferences directly within your `game.project` file. This allows you to customize the log message format, log levels, and other settings based on your project's requirements.

This is a default configuration for the Log module, all fields are optional, and this is a default value:

```ini
[log]
level = TRACE
level_release = ERROR
info_block = %levelname[%logger]
message_block = %space%message: %context %tab<%function>
logger_block_width = 14
max_log_length = 1024
inspect_depth = 1
```

This configuration section for `game.project` defines various settings:

| Setting             | Description                                                                                                                                                                                                 | Default Value     |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------| ------------------- |
| **level**           | Sets the default logging level for development builds. In this case, `TRACE` and above levels will be logged, providing detailed information for debugging and monitoring.                                   | `TRACE`             |
| **level_release**   | Determines the logging level for release builds, where `ERROR` and above levels will be logged, focusing on warnings and errors that are critical for a production environment. Use `FATAL` to silence all logs. | `ERROR`             |
| **info_block**      | Defines the format of the info block in log messages, which includes the log level and logger name in this configuration.                                                                                     | `%levelname[%logger]` |
| **message_block**   | Sets the format for the message block, including the actual log message, any context provided, and the function from which the log was called.                                                               | `%space%message: %context %tab<%function>` |
| **logger_block_width** | Defines the width of the logger block in log messages. This helps in aligning log messages for better readability. Default is 14.                                                                          | `14` |
| **max_log_length**  | The maximum length of the log message. If the message exceeds this length, it will be truncated. Default is 1024.                                                                                            | `1024` |
| **inspect_depth**   | The maximum depth of nested tables to inspect when logging. Default is 1.                                                                                                                                    | `1` |

In the `[log]` configuration section for `game.project`, the `info_block` and `message_block` fields allow for dynamic content based on specific placeholders. These placeholders get replaced with actual log information at runtime, providing structured and informative log messages.

### Info Block Placeholders

| Placeholder          | Description                                                                                                                                                                                                 |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **%logger**          | The name of the logger instance producing the log message. Helps in identifying the source of the log message.                                                                                               |
| **%levelname**       | The name of the log level (e.g., DEBUG, INFO, WARN, etc.). Provides clarity on the severity or nature of the log message. Should be placed at the beginning of the log message for color highlighting in the Defold Console. |
| **%levelshort**      | The short name of the log level (e.g., D, I, W, E). Provides a compact representation of the log level. But Defold Console will be not able to highlight it.                                                 |
| **%time_tracking**   | The time elapsed since the last entry in this logger instance. Time tracking will be enabled, if this placeholder is used.                                                                                   |
| **%memory_tracking** | The memory allocated since the last entry in this logger instance. Memory tracking will be enabled, if this placeholder is used.                                                                             |
| **%chronos_tracking**| The time elapsed since the last entry in this logger instance. Chronos extension will be used, if this placeholder is used.                                                                                  |

### Message Block Placeholders

| Placeholder  | Description                                                                                                                                                                                                 |
|--------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **%tab**     | A tab character for formatting log messages.                                                                                                                                                                |
| **%space**   | A space character for formatting log messages. Usually used before or end of the message, where you can't use just space in game.project.                                                                         |
| **%message** | The actual log message content. This is the primary information you want to log.                                                                                                                            |
| **%context** | Any additional context provided along with the log message. It can be useful for providing extra information relevant to the log message (e.g., variable values, state information).                        |
| **%function**| The function name or location from where the log message was generated. Helps in pinpointing where in the codebase a particular log message is coming from, aiding in debugging.                             |


### Output Prefabs

```ini
[log]
info_block = %levelname[%logger]
message_block = %space%message: %context %tab<%function>
```

**Preview:**

```
DEBUG:[game.logger     ] Debug message: {debug: message, value: 2} 	<example/example.gui_script:17>
```

---

```ini
[log]
info_block = %levelname| %time_tracking | %memory_tracking | %logger
message_block = | %tab%message: %context %tab<%function>
```

**Preview:**

```
DEBUG:| 166.71ms |   2.4kb | game.logger      |	Delayed message: just string 	<example/example.gui_script:39>
```

## Memory Tracking

To enable memory tracking, add `%memory_tracking` to the `info_block` in the `game.project` file:

```ini
info_block = %levelname| %memory_tracking | %logger
```

This will include memory tracking information in the log messages, showing the memory allocated since the last entry in this logger instance.

>DEBUG:|   2.4kb | game.logger      |	Delayed message: just string 	<example/example.gui_script:39>`.

Works only in debug mode, automatically disabled in release mode.


## Time Tracking

To enable time tracking, add `%time_tracking` to the `info_block` in the `game.project` file:

```ini
info_block = %levelname| %time_tracking | %logger
```

This will include time tracking information in the log messages, showing the time elapsed since the last entry in this logger instance.

>DEBUG:|  0.01ms | game.logger      |	Delayed message: just string 	<example/example.gui_script:39>`.


## Using High Resolution Timer Extension

The Log module can utilize the Chronos extension for Defold to enable time tracking with microsecond or better precision (`QueryPerformanceCounter` on Windows). This is optional.

If you want to use the extension, add the following line to the dependencies field in your `game.project` file:

**[defold-chronos](https://github.com/d954mas/defold-chronos)**
```
https://github.com/d954mas/defold-chronos/archive/refs/tags/1.0.1.zip
```

Then to use the high-resolution timer, you need to add `%chronos_tracking` to the `info_block` in the `game.project` file:

```ini
[log]
info_block = %levelname| %chronos_tracking | %logger
```

This will include time tracking information in the log messages, showing the time elapsed since the last entry in this logger instance.

>DEBUG:|  0.00001ms | game.logger      |	Delayed message: just string 	<example/example.gui_script:39>`.


## Using Native UTF8 Extension

The Log module can utilize the native UTF8 extension for Defold to handle UTF-8 strings. This is optional but recommended for better performance.

If you want to use the native UTF8 extension, add the following line to the dependencies field in your `game.project` file:

**[defold-utf8](https://github.com/d954mas/defold-utf8)**
```
https://github.com/d954mas/defold-utf8/archive/master.zip
```

The Log module automatically detects the presence of the native UTF8 extension and uses it if available. If the extension is not present, the Log module will use the built-in Lua string functions.

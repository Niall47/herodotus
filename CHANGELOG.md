# Changelog
All notable changes to this project will be documented in this file.

## [2.3.1] - 2025-09-30
- New config option to colour the log prefix, either the whole string or individual components
- New config option to control if output files should retain colours
- Optional argument to queue log messages then release later

## [2.2.1] - 2025-09-15
- Fixed issue with ANSI exit codes breaking on string interpolation
- Added strip_colour method to String which we now call when sending logs to file
- Added colours/styles: yellow, bg_yellow, bg_white, bg_bright_red, bg_bright_green, bg_bright_blue, bg_bright_magenta, bg_bright_cyan, dim
- Removed colours/styles: bright_black (that's just gray), bright_yellow (that's just yellow), blink (inconsistent/unsupported)
- Added a changelog


## [2.2.0] - 2025-09-08
- Added colourise method to handle colour exist codes
- Added alias for colour/color
- Added alias for brown/yellow

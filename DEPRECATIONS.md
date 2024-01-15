# Deprecations in AppleSimulatorUtils

As of January 2024, we've identified overlapping functionalities between **AppleSimulatorUtils** and **`xcrun simctl`** command in the latest **Command Line Tools for Xcode**. 
This has led to the deprecation of several commands in **AppleSimulatorUtils**.

For detailed usage of the **`xcrun simctl`** command, run `xcrun simctl --help`.

## Deprecated Commands

The commands listed below are now deprecated in **AppleSimulatorUtils**, and can be replaced with corresponding **`xcrun simctl`** commands:

### `--setPermissions` Options

The following `--setPermissions` options in **AppleSimulatorUtils** are deprecated and can be replaced with corresponding `xcrun simctl privacy` commands:

- `calendar`
- `contacts`
- `location`
- `photos`
- `medialibrary` _(Use `media-library` in `xcrun simctl privacy`)_
- `microphone`
- `motion`
- `reminders`
- `siri`

For detailed usage of the simctl privacy commands, run `xcrun simctl privacy --help`.

### `--setLocation` Command

The `--setLocation` command is deprecated. Use `xcrun simctl location` instead.

For detailed usage of the location command, run `xcrun simctl location --help`.

## Additional Notes

While most of the deprecated commands are still available and function in **AppleSimulatorUtils**,
some may show regressions (especially in newer versions of iOS and Xcode).

If you encounter any issues,
the recommended solution is to use **`xcrun simctl`** instead,
as it is more up-to-date and maintained by Apple.

---

**We will continue to maintain AppleSimulatorUtils for non-overlapping functionalities only.**


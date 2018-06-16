# AppleSimulatorUtils
A collection of utils for Apple simulators.

## Installing

Install [brew](https://brew.sh), then:

```shell
brew tap wix/brew
brew install wix/brew/applesimutils
```
(If xcode-select: error: tool 'xcodebuild' requires Xcode)
try ```sudo xcode-select -s /Applications/Xcode.app/Contents/Developer```

## Usage

```shell
Usage:
    applesimutils --byId <simulator identifier> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --byName <simulator name> --byOS <simulator OS version> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --simulator <simulator name/identifier> --restartSB
    applesimutils --list [--byName <simulator name>] [--byOS <simulator OS version>] [--byType <simulator OS version>] [--maxResults <int>]

Options:
    --byId             Filters simulators by identifier
    --byName           Filters simulators by name
    --byType           Filters simulators by device type
    --byOS             Filters simulators by operating system
    --list             Lists available simulators
    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect
    --clearKeychain    Clears the simulator's keychain
    --restartSB        Restarts SpringBoard
    --bundle           The app bundle identifier
    --maxResults       Limits the number of results returned from --list
    --version, -v      Prints version
    --help, -h         Prints usage

Available Permissions:
    calendar=YES|NO|unset
    camera=YES|NO|unset
    contacts=YES|NO|unset
    health=YES|NO|unset
    homekit=YES|NO|unset
    location=always|inuse|never|unset
    medialibrary=YES|NO|unset
    microphone=YES|NO|unset
    motion=YES|NO|unset
    notifications=YES|NO|unset
    photos=YES|NO|unset
    reminders=YES|NO|unset
    siri=YES|NO|unset
    speech=YES|NO|unset
```

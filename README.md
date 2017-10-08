# AppleSimulatorUtils
A collection of utils for Apple simulators.

## Installing

Install [brew](https://brew.sh), then:

```shell
brew tap wix/brew
brew install wix/brew/applesimutils
```

## Usage

```shell
Usage: applesimutils --simulator <simulator name/identifier> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
       applesimutils --simulator <simulator name/identifier> --restartSB
       applesimutils --list ["<simulator name>[, OS=<version>]"] [--maxResults <int>]

Options:
    --simulator        The simulator identifier or simulator name & operating system version (e.g. "iPhone 7 Plus, OS = 10.3")
    --bundle           The app bundle identifier
    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect
    --restartSB        Restarts SpringBoard
    --list       		 Lists available simulators; an optional filter can be provided: simulator name is required, os version is optional
    --maxResults       Limits the number of results returned from --list
    --version, -v      Prints version
    --help, -h         Prints usage

Available permissions:
    calendar=YES|NO
    camera=YES|NO
    contacts=YES|NO
    health=YES|NO
    homekit=YES|NO
    location=always|inuse|never
    medialibrary=YES|NO
    microphone=YES|NO
    motion=YES|NO
    notifications=YES|NO
    photos=YES|NO
    reminders=YES|NO
    siri=YES|NO
```

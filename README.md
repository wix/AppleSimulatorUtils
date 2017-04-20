# AppleSimulatorUtils
A collection of utils for Apple simulators.

## Installing

Install [brew](https://brew.sh), then:

```shell
brew tap wix/brew
brew install --HEAD applesimutils
```

## Usage

```shell
Usage: applesimutils --simulator <simulator name/identifier> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
       applesimutils --simulator <simulator name/identifier> --restartSB

Options:
    --simulator        The simulator identifier or simulator name & operating system version ("iPhone 6S Plus,OS=10.3"
    --bundle           The app bundle identifier
    --setPermissions   Sets the specified permissions and restarts SpringBoard for the changes to take effect
    --restartSB        Restarts SpringBoard
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

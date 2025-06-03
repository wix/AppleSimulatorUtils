# AppleSimulatorUtils
A collection of utils for Apple simulators.

## Deprecation Notice

**AppleSimulatorUtils** remains an actively maintained project.
However, we have deprecated certain functionalities that overlap with features provided by the **`xcrun simctl`** command in the latest **Command Line Tools for Xcode**. 
In addition to avoid redundancy, it is better to use the **official** tool provided by Apple.

For a comprehensive list of deprecated commands and their `xcrun simctl` alternatives, please refer to our [Deprecations Document](./DEPRECATIONS.md).


## Installing

Install [brew](https://brew.sh), then:

```shell
brew tap wix/brew
brew install applesimutils
```

## Usage

```
A collection of utils for Apple simulators.

Usage Examples:
    applesimutils --byId <simulator UDID> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --byName <simulator name> --byOS <simulator OS> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --list [--byName <simulator name>] [--byOS <simulator OS>] [--byType <simulator device type>] [--maxResults <int>] [--fields <key1,key2,...>]
    applesimutils --booted --biometricEnrollment <YES/NO>
    applesimutils --booted --biometricMatch

Options:
    --byId, -id                   Filters simulators by unique device identifier (UDID)
    --byName, -n                  Filters simulators by name
    --byType, -t                  Filters simulators by device type
    --byOS, -o                    Filters simulators by operating system
    --booted, -bt                 Filters simulators by booted status

    --list, -l                    Lists available simulators
    --bundle, -b                  The app bundle identifier
    --maxResults                  Limits the number of results returned from --list
    --fields                      Comma-separated list of fields to include in --list output (e.g. "udid,os,identifier")

    --setPermissions, -sp         Sets the specified permissions and restarts SpringBoard for the changes to take effect
    --clearKeychain, -ck          Clears the simulator's keychain
    --clearMedia, -cm             Clears the simulator's media
    --restartSB, -sb              Restarts SpringBoard

    --biometricEnrollment, -be    Enables or disables biometric (Face ID/Touch ID) enrollment.
    --biometricMatch, -bm         Approves a biometric authentication request with a matching biometric feature (e.g. face or finger)
    --biometricNonmatch, -bnm     Fails a biometric authentication request with a non-matching biometric feature (e.g. face or finger)

    --version, -v                 Prints version
    --help, -h                    Prints usage

Available Permissions:
    calendar=YES|NO|unset
    camera=YES|NO|unset
    contacts=YES|NO|unset
    faceid=YES|NO|unset
    health=YES|NO|unset (iOS/tvOS 12.0 and above)
    homekit=YES|NO|unset
    location=always|inuse|never|unset
    medialibrary=YES|NO|unset
    microphone=YES|NO|unset
    motion=YES|NO|unset
    notifications=YES|NO|critical|unset
    photos=YES|NO|limited|unset (“limited” supported on iOS/tvOS 14.0 and above)
    reminders=YES|NO|unset
    siri=YES|NO|unset
    speech=YES|NO|unset
    userTracking=YES|NO|unset (iOS/tvOS 14.0 and above)
```

## Troubleshooting

- In case an installation fails, make sure to update your command line tools in the System Update system preference pane of your Mac
- If Homebrew complains about a conflict in the `wix/brew` tap, run `brew untap wix/brew && brew tap wix/brew` and try installing again
- If installation still fails, **run `brew doctor` and fix all issues & warnings**

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

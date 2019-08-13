# AppleSimulatorUtils
A collection of utils for Apple simulators.

## Installing

Install [brew](https://brew.sh), then:

```shell
brew tap wix/brew
brew install applesimutils
```

## Troubleshooting

- In case an installation fails, make sure to update your command line tools in the System Update system preference pane of your Mac
- If Homebrew complains about a conflict in the `wix/brew` tap, run `brew untap wix/brew && brew tap wix/brew` and try installing again
- If installation still fails, **run `brew doctor` and fix all issues & warnings**

## Usage

```
A collection of utils for Apple simulators.

Usage Examples:
    applesimutils --byId <simulator UDID> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --byName <simulator name> --byOS <simulator OS> --bundle <bundle identifier> --setPermissions "<permission1>, <permission2>, ..."
    applesimutils --list [--byName <simulator name>] [--byOS <simulator OS>] [--byType <simulator device type>] [--maxResults <int>]
    applesimutils --byId <simulator UDID> --biometricEnrollment <YES/NO>
    applesimutils --byId <simulator UDID> --matchFace

Options:
    --byId                       Filters simulators by unique device identifier (UDID)
    --byName                     Filters simulators by name
    --byType                     Filters simulators by device type
    --byOS                       Filters simulators by operating system
    --list                       Lists available simulators
    --setPermissions             Sets the specified permissions and restarts SpringBoard for the changes to take effect
    --clearKeychain              Clears the simulator's keychain
    --restartSB                  Restarts SpringBoard
    --biometricEnrollment        Enables or disables biometric (Face ID/Touch ID) enrollment.
    --matchFace                  Approves Face ID authentication request with a matching face
    --unmatchFace                Fails Face ID authentication request with a non-matching face
    --matchFinger                Approves Touch ID authentication request with a matching finger
    --unmatchFinger              Fails Touch ID authentication request with a non-matching finger
    --bundle                     The app bundle identifier
    --maxResults                 Limits the number of results returned from --list
    --version, -v                Prints version
    --help, -h                   Prints usage

Available Permissions:
    calendar=YES|NO|unset
    camera=YES|NO|unset
    contacts=YES|NO|unset
    health=YES|NO|unset (iOS 12.0 and above)
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
    faceid=YES|NO|unset
```

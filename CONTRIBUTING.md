# Contributing to AppleSimulatorUtils (ASU)
So, you want to contribute to ASU? Great! 👏 
Here are a few guidelines that will help you along the way. There are many ways to contribute, and we appreciate all of them.

## Before you start

ASU is a collection of utils for Apple simulators.
It is a command line tool that allows you to set permissions for apps running on simulators, clear the simulator's keychain and media, and more.

We created this tool on Wix to help us with our development and testing, and it is mainly used by our testing framework, [Detox](https://wix.github.io/Detox/) (which is also an open source project), but can be used independently.

### Asking questions
If you have a question, please open an issue in the Issues section of the project. Feel free to ask anything, even if you're not sure it's a bug or an enhancement. We'll do our best to answer, or redirect you to the right place.
The more information you provide, the better we can help you.

### Reporting bugs
If you find a bug, please report it in the [issues](http://github.com/wix/AppleSimulatorUtils/issues) section of the project.

### Suggesting enhancements
For feature requests or suggestions, please open an issue in the Issues section of the project. Please provide as much information as possible, to help us understand what you're looking for.
If you'd like to implement a new feature, please submit an issue with a proposal for your work first, to be sure that we can use it. When you are ready to start, please follow the instructions in the [Contributing code](#contributing-code) section below.

### Help others
Help others by answering questions in the Issues section. If you see a question that you know the answer to, please help out! It's a great way to learn, and to help others.

### We ❤️ Pull Requests!
**We are happy to accept contributions to ASU from the community!**
Please read the following [guidelines](#contributing-code) before you start working on a pull request.


## Contributing code

ASU is a homebrew package, therefore it can be installed using the `brew` command:
```shell
brew tap wix/brew
brew install applesimutils
```

However, if you are interested in changing ASU code and to contribute to it, the following steps are required.
1. Clone the repository to your local machine.
2. Make sure you have Xcode installed.
3. Open the `applesimutils.xcodeproj` file in Xcode.
4. Make your changes.
5. Build the project from the Xcode: `Product > Build` or `⌘B`.
6. Set the scheme launch arguments to the desired command line arguments you want to test (e.g. `--list`). This can be done by clicking on the scheme name in the top left corner of Xcode, and then selecting `Edit Scheme...`. In the `Arguments` tab, select or add the desired arguments to the `Arguments Passed On Launch` section. 
7. Run and play with the tool from the Xcode: `Product > Run` or `⌘R`. 
   1. Set breakpoints to debug your changes.
   2. Plan a manual test scenario and run it (unfortunately, we don't have automated tests for this project). Make sure the output is as expected.
8. Commit your changes and open a pull request. 
   1. Add a description of your changes.
   2. Describe how to test them (how you tested them).
   3. Add a link to the issue you are fixing, if there is one.
9. Wait for the pull request to be reviewed our team and merged.
10. If everything went well, your changes will be available in the next release of ASU. 

Thank you for your contribution! 🎉

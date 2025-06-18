# 🔧 Releasing `wix/AppleSimulatorUtils`

Follow these steps to publish a new version of AppleSimUtils:

### 1. Pre-flight Check

* Make sure you **can push to `master` directly** — the release script currently depends on this.
* Ensure your feature is committed, tested, and working.

### 2. Run the Release Script

```bash
./releaseVersion.sh <YOUR_VERSION>
# e.g.
./releaseVersion.sh 0.9.12
```

In the interim, it will open your default Markdown editor (e.g., Xcode) with an empty release notes document for you to fill out.
Add your release notes, then **QUIT the app completely** (closing the window may not be enough).

The script will attempt to:

* Commit and tag the release in **AppleSimulatorUtils**
* Push a formula update to [`wix-incubator/homebrew-brew`](https://github.com/wix-incubator/homebrew-brew)

> [!WARNING]
>
> If the Homebrew formula update fails (e.g., wrong hash, bad URL), it might leave a broken or partial release.
>
> * You may need to unblock it by committing an empty change:
>
>   ```bash
>   git commit --allow-empty -m "Trigger retry for release <version>"
>   ```
> * Then re-run the release script.

### 3. Update Homebrew Hashes

> [!IMPORTANT]
> **Known Bug!** The release script **does not update Homebrew hashes correctly** on the first try, so you **MUST** execute this step immediately afterwards.

After the GitHub release is live (e.g., [v0.9.12](https://github.com/wix/AppleSimulatorUtils/releases/tag/0.9.12)), look under **Assets** for SHA256 hashes:

```
AppleSimulatorUtils-0.9.12.tar.gz
sha256:4d6d02...
...
```

Edit the formula here:
👉 [`applesimutils.rb`](https://github.com/wix-incubator/homebrew-brew/blob/master/Formula/applesimutils.rb)

Update the `sha256` fields with the correct values from the GitHub release.

### 4. Final Check ✅

```bash
brew update
brew install applesimutils
applesimutils --version
```

Ensure the installed binary matches your new version and works correctly.

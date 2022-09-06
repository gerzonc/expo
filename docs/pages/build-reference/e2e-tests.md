---
title: Running E2E tests on EAS Build
sidebar_title: Running E2E tests
---

import { Collapsible } from '~/ui/components/Collapsible';
import { Terminal } from '~/ui/components/Snippet';

> **Warning**: EAS Build support for E2E testing is in a _very early_ state. The intention of this guide is to explain how you can run E2E tests on the service today, without all of the affordances that we plan to build in the future. This guide will evolve over time as support for testing workflows in EAS Build improves.

> **Android not yet supported**: EAS Build does not yet support running tests on an Android Emulator — this will be coming soon.

With EAS Build, you can build a workflow for running E2E tests for your application. In this guide, you will learn how to use one of the most popular libraries ([Detox](https://wix.github.io/Detox)) to do that.

This guide explains how to run E2E tests with Detox in a bare workflow project. You can use [@config-plugins/detox](https://github.com/expo/config-plugins/tree/main/packages/detox) for a managed project, but you may need to adjust some of the instructions in this guide in order to do so.

## Running iOS tests

### 0. Initialize a new Bare Workflow project

Let's start by initializing a new Expo project and running `expo prebuild` to generate the native projects.

<Terminal cmd={[
'# Initialize a new project',
'$ yarn create expo-app eas-tests-example',
'# cd into the project directory',
'$ cd eas-tests-example',
'# Generate native code',
'$ yarn expo prebuild --platform ios'
]} />

### 1. Make home screen interactive

The first step to writing E2E tests is to have something to test - we have an empty app, so let's make our app interactive. We can add a button and display some new text when it's pressed.
Later, we're going to write a test that's going to tap the button and check whether the text has been displayed.

<img src="/static/images/eas-build/tests/01-click-me.png" style={{maxWidth: "50%" }} />
<img src="/static/images/eas-build/tests/02-hi.png" style={{maxWidth: "50%" }} />

<Collapsible summary="👀 See the source code">

```js
// App.js
import { StatusBar } from 'expo-status-bar';
import { useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

export default function App() {
  const [clicked, setClicked] = useState(false);

  return (
    <View style={styles.container}>
      {!clicked && (
        <Pressable testID="click-me-button" style={styles.button} onPress={() => setClicked(true)}>
          <Text style={styles.text}>Click me</Text>
        </Pressable>
      )}
      {clicked && <Text style={styles.hi}>Hi!</Text>}
      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
  },
  hi: {
    fontSize: 30,
    color: '#4630EB',
  },
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    paddingHorizontal: 32,
    borderRadius: 4,
    elevation: 3,
    backgroundColor: '#4630EB',
  },
  text: {
    fontSize: 16,
    lineHeight: 21,
    fontWeight: 'bold',
    letterSpacing: 0.25,
    color: 'white',
  },
});
```

</Collapsible>

### 2. Set up Detox

#### Install dependencies

Let's add two development dependencies to the project - `jest` and `detox`. `jest` (or `mocha`) is required because `detox` does not have its own test-runner.

<Terminal cmd={[
'# Install jest & detox',
'$ yarn add -D jest detox',
'# Create Detox configuration files',
'$ yarn detox init -r jest',
]} />

> See the official Detox docs at https://wix.github.io/Detox/docs/introduction/getting-started/ and https://wix.github.io/Detox/docs/guide/jest to learn about any potential updates to this process.

#### Configure Detox

Detox requires you to specify both the build command and path to the binary produced by it. Technically, the build command is not necessary when running tests on EAS Build, but allows you to run tests locally (using `yarn detox build --configuration ios`).

Edit **.detoxrc.json** and replace the `ios` configuration with:

```json
// .detoxrc.json
{
  "apps": {
    "ios": {
      "type": "ios.app",
      // note: replace "eastestsexample" with your project's name
      "build": "xcodebuild -workspace ios/eastestsexample.xcworkspace -scheme eastestsexample -configuration Release -sdk iphonesimulator -arch x86_64 -derivedDataPath ios/build",
      // note: replace "eastestsexample" with your project's name
      "binaryPath": "ios/build/Build/Products/Release-iphonesimulator/eastestsexample.app"
    }
  }
}
```

### 3. Write E2E tests

Next, we'll add our first E2E tests. Delete the auto-generated **e2e/firstTest.e2e.js** and create our own **e2e/homeScreen.e2e.js** with the following contents:

```js
// homeScreen.e2e.js
describe('Home screen', () => {
  beforeAll(async () => {
    await device.launchApp();
  });

  beforeEach(async () => {
    await device.reloadReactNative();
  });

  it('"Click me" button should be visible', async () => {
    await expect(element(by.id('click-me-button'))).toBeVisible();
  });

  it('shows "Hi!" after tapping "Click me"', async () => {
    await element(by.id('click-me-button')).tap();
    await expect(element(by.text('Hi!'))).toBeVisible();
  });
});
```

There are two tests in the suite:

- One that checks whether the "Click me" button is visible on the home screen.
- Another that verifies that tapping the button triggers displaying "Hi!".

Both tests assume the button has the `testID` set to `click-me-button`. See [the source code](#1-make-home-screen-interactive) for details.

### 4. Configure EAS Build

Now that we have configured Detox and written our first E2E test, let's configure EAS Build and run the tests in the cloud.

#### Create eas.json

The following command creates [eas.json](/build/eas-json.md) in the project's root directory:
<Terminal cmd={['$ eas build:configure']} />

#### Configure EAS Build

There are three more steps to configure EAS Build for running E2E tests as part of the build:

- Detox tests are run in the iOS simulator. We will define a build profile that builds your app for simulator.
- Install the [`applesimutils`](https://github.com/wix/AppleSimulatorUtils) command line util required by Detox.
- Configure EAS Build to run Detox tests after successfully building the app.

Edit **eas.json** and add the `test` build profile:

```json
// eas.json
{
  "build": {
    "test": {
      "ios": {
        "simulator": true
      }
    }
  }
}
```

Create **eas-hooks/eas-build-pre-install.sh** that will be used to install `applesimutils` with `brew`:

```sh
#!/usr/bin/env bash

set -eox pipefail

if [[ "$EAS_BUILD_PLATFORM" == "ios" && "$EAS_BUILD_PROFILE" == "test" ]]; then
  brew tap wix/brew
  brew install applesimutils
fi
```

Next, create **eas-hooks/eas-build-on-success.sh** with the following contents. The script runs Detox tests in headless mode:

```sh
#!/usr/bin/env bash

set -eox pipefail

if [[ "$EAS_BUILD_PLATFORM" == "ios" && "$EAS_BUILD_PROFILE" == "test" ]]; then
  detox test --configuration ios --headless
fi
```

Edit **package.json** to use [EAS Build hooks](/build-reference/npm-hooks.md) to run the above scripts on EAS Build:

```json
// package.json
{
  "scripts": {
    "eas-build-pre-install": "./eas-hooks/eas-build-pre-install.sh",
    "eas-build-on-success": "./eas-hooks/eas-build-on-success.sh"
  }
}
```

> Don't forget to add executable permissions to **eas-build-pre-install.sh** and **eas-build-on-success.sh**. Run `chmod +x eas-hooks/*.sh`.

### 5. Run tests on EAS Build

Running the tests on EAS Build is like running a regular build:

<Terminal cmd={['$ eas build -p ios --profile test']} />

If you have set up everything correctly you should see the successful test result in the build logs:

<img src="/static/images/eas-build/tests/03-logs.png" style={{maxWidth: "100%" }} />

### 6. Upload screenshots of failed test cases

This step is optional but highly recommended. When an E2E test case fails, it can be helpful to see the screenshot of the application state. EAS Build makes it easy to upload any arbitrary build artifacts using the [`buildArtifactPaths`](/build-reference/eas-json.md#buildartifactpaths) field in **eas.json**.

#### Take screenshots for failed tests

[Detox supports taking in-test screenshots of the device](https://wix.github.io/Detox/docs/api/screenshots). It exposes the `device.takeScreenshot()` function that can be called from any test case.

We want to take the screenshot only for failed test cases. Unfortunately, neither `jest` nor `detox` offers a simple way to detect whether a paricular test case has failed. We will implement our own mechanism for that.

Let's start by editing **e2e/environment.js** and adding the `handleTestEvent` method to the `CustomDetoxEnvironment` class. The function handles test events and sets a global `testFailed` variable in the case of test case failure. See the snippet below:

```ts
// e2e/environment.js
class CustomDetoxEnvironment extends DetoxCircusEnvironment {
  // ...

  async handleTestEvent(event, state) {
    const { name } = event;

    if (['test_start', 'test_fn_start'].includes(name)) {
      this.global.testFailed = false;
    }

    if (name === 'test_fn_failure') {
      this.global.testFailed = true;
    }

    await super.handleTestEvent(event, state);
  }
}
```

After modifying the environment class, we can define an `afterEach` hook that calls `device.takeScreenshot()` for failed tests. Create the `e2e/setup.ts` file with the following contents:

```ts
// e2e/setup.ts
afterEach(async () => {
  if (testFailed) {
    await device.takeScreenshot('screenshot');
  }
});
```

The last step is to configure `jest` to load `e2e/setup.ts` before running tests. This way we don't need to include the `afterEach` hook in every test suite:

```json
// e2e/config.json
{
  /// ...
  "setupFilesAfterEnv": ["./setup.js"]
}
```

After making those changes, screenshots for failed tests will be saved to the `artifacts` directory.

#### Configure EAS Build for screenshots upload

Edit **eas.json** and add `buildArtifactPaths` to the `test` build profile:

```json
// eas.json
{
  "build": {
    "test": {
      "ios": {
        "simulator": true,
        "buildArtifactPaths": ["artifacts/**/*.png"]
      }
    }
  }
}
```

In contrast to `applicationArchivePath`, the build artifacts defined at `buildArtifactPaths` will be uploaded even if the build fails. All `.png` files from the `artifacts` directory will be packed into a tarball and uploaded to AWS S3. You can later download them from the build details page.

If you run E2E tests locally, remember to add `artifacts` to `.gitignore`:

```stylus
// .gitignore
artifacts/
```

#### Break a test and run a build

In order to test our new configuration, let's break a test and see that EAS Build uploads the screenshots.

Edit `e2e/homeScreen.e2e.js` and make the following change:

```diff
diff --git a/e2e/homeScreen.e2e.js b/e2e/homeScreen.e2e.js
index e28acfa..c65e90c 100644
--- a/e2e/homeScreen.e2e.js
+++ b/e2e/homeScreen.e2e.js
@@ -8,7 +8,7 @@ describe('Home screen', () => {
   });

   it('"Click me" button should be visible', async () => {
-    await expect(element(by.id('click-me-button'))).toBeVisible();
+    await expect(element(by.id('click-me-button'))).not.toBeVisible();
   });

   it('shows "Hi!" after tapping "Click me"', async () => {
```

Run a build with `eas build -p ios --profile test` and wait for the build to finish. After going to the build details page you should see that the build failed. Use the **"Download artifacts"** button to download and examine the screenshot:

<img src="/static/images/eas-build/tests/04-artifacts.png" style={{maxWidth: "100%" }} />

## Repository

The full example from this guide is available at https://github.com/expo/eas-tests-example.

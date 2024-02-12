# dmg-notary
A Swift command line tool for creating DMG and notarizing mac apps using the Apple notary service.
Inspired by [dmgdist](https://github.com/insidegui/dmgdist).

## Requirements
- [`create-dmg`](https://github.com/sindresorhus/create-dmg) is needed to generate DMGs.
- Xcode 14 or later.

## Usage
```
OVERVIEW: Create a DMG and notarize it for distribution using the Apple notary service.

USAGE: dmg-notary <app-file-path> [--identity <identity>] [--dmg-name <dmg-name>] [--team-id <team-id>] [--apple-id <apple-id>] [--password <password>] [--keychain-profile <keychain-profile>] [--verbose]

ARGUMENTS:
  <app-file-path>         Path to the developer ID signed .app (doesn't have to
                          be notarized)

OPTIONS:
  --identity <identity>   Your code signing identity, such as "Developer ID
                          Application: John Doe (XXXX123YY)". If not specified,
                          create-dmg will attempt to pick one from your
                          Keychain.
  --dmg-name <dmg-name>   Custom name for the output DMG file (max 27
                          characters)
  --team-id <team-id>     Your App Store Connect provider ID (same as your
                          developer's team ID)
  --apple-id <apple-id>   Your Developer ID (App Store Connect e-mail)
  --password <password>   App-specific password for your Apple ID. You will
                          be given a secure prompt on the command line if Apple
                          ID and Team ID are provided and '--password' option
                          is not specified.
  --keychain-profile <keychain-profile>
                          Authenticate with credentials stored in the Keychain
                          for notarytool.
  --verbose               Verbose output
  -h, --help              Show help information.
```

### Authentication
To authenticate with the Apple notary service ([notarytool](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)), you need to enter your credentials (`--team-id`, `--apple-id`, `--password`). `--password` is an [app-specific password](https://support.apple.com/en-gb/102654) for your Apple ID. If you don't want to provide the password in clear text, you can omit it in the command and enter it later when prompted.

Alternatively, you can provide a reference to a keychain item instead of your credentials. This assumes the keychain holds a keychain item for your credentials. You can add a new keychain item for this purpose from the command line using the notarytool utility:
```
$ xcrun notarytool store-credentials "notarytool-password"
               --apple-id "<AppleID>"
               --team-id <DeveloperTeamID>
               --password <secret_2FA_password>
```

### Expected output
After running dmg-notary, if successfully, you will find a notarized and stapled DMG file in the same folder with your input .app file. A log will also be saved to the same folder to give more insight into the notarization step - which would be helpful if your submission fails.

## Installation using [Mint](https://github.com/yonaskolb/mint)

You can install dmg-notary using Mint as follows:

```
$ mint install itsmeichigo/dmg-notary
```

## Development

- Clone and `cd` into the repository.
- Run the following command to try it out:

```
$ swift run dmg-notary --help
```

## Contribution
This tool is very simple and is designed to automate the process of creating, uploading and stapling a DMG for a Mac app. If you find any issues, feel free to open a pull request with the fix.

## Alternative notarization method
A simpler way to notarize mac apps is to add a post-action script to the Archive step of your app's scheme. More details can be found [here](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow/customizing_the_xcode_archive_process).

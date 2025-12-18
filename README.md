# Bridge Extension for Defold

The `bridge` extension helps you work with multiple SDK plugins in Defold. You can easily integrate and use these plugins by calling only the methods from `bridge.lua`.

> This extension is just a set of wrappers over SDKs to unify their usage. You are welcome to visit the [pull request page](https://github.com/KassiaL/bridge/pulls) and add your own wrappers, making it easy for everyone to use any existing SDK in a unified way.

## Supported SDKs

- Web platforms (HTML5)
  - Playgama
  - GamePush
- Ads (mobile)
  - Appodeal
- Analytics (mobile)
  - Firebase Analytics
- In-app purchases (mobile)
  - Defold IAP

## Setup

Open your `game.project` file and add the following line to the `dependencies` field under the `[project]` section:

```
https://github.com/KassiaL/bridge/archive/main.zip
https://github.com/subsoap/defsave/archive/master.zip
```

DefSave is required for local storage (`bridge.storage.set_local/get_local`).

## SDK Dependencies

Add the dependencies for the SDKs you want to use. Each SDK may require one or more dependencies:

### Playgama

Required: [Playgama SDK](https://github.com/KassiaL/playgama_sdk), [JSToDef](https://github.com/AGulev/jstodef)

```
https://github.com/KassiaL/playgama_sdk/archive/main.zip
https://github.com/AGulev/jstodef/archive/refs/tags/3.0.0.zip
```

### GamePush

Required: [GamePush](https://github.com/megalanthus/defold-gamepush/archive/master.zip)

```
https://github.com/megalanthus/defold-gamepush/archive/master.zip
```

### Appodeal

Required: [Appodeal](https://github.com/KassiaL/appodeal)

```
https://github.com/KassiaL/appodeal/archive/master.zip
```

### Defold IAP

Required: [Defold IAP](https://github.com/defold/extension-iap)

```
https://github.com/defold/extension-iap/archive/master.zip
```

### Firebase Analytics

Required: [Firebase](https://github.com/defold/extension-firebase), [Firebase Analytics](https://github.com/defold/extension-firebase-analytics)

```
https://github.com/defold/extension-firebase/archive/master.zip
https://github.com/defold/extension-firebase-analytics/archive/master.zip
```

## Integration Example

```lua
local bridge = require("bridge.bridge")
local bridge_mock = require("bridge.mock")
local bridge_firebase = require("bridge.firebase")
local bridge_playgama = require("bridge.playgama")
local bridge_gamepush = require("bridge.gamepush")
local bridge_appodeal = require("bridge.appodeal")
local defold_iap = require("bridge.defold_iap")
local device = require("m.stuff.device")

if html5 then
    bridge.init_sdks({ bridge_playgama, bridge_mock })
elseif device.mobile() then
    bridge_appodeal.set_test_ads(false)
    bridge.init_sdks({ bridge_firebase, bridge_appodeal, defold_iap, bridge_mock })
else
    bridge.init_sdks({ bridge_mock })
end
```

All SDKs are connected in sequence and do NOT overwrite each other's methods. That's why `bridge_mock` is connected last, to stub any methods not implemented in previous SDKs.

You can then use the universal method `run_after_sdk_init`, which calls your callback after SDK initialization is complete. If the SDKs are already initialized, the callback is called immediately:

```lua
bridge.run_after_sdk_init(function()
    bridge.utils.send_platform_message("game_ready")
    if bridge.payments.is_supported() then
        local purchases_id_list = get_all_purchases_id_list()
        bridge.payments.get_catalog(purchases_id_list, function(catalog)
            _G.catalog = catalog
        end)
    end
end)
```

## Autocomplete and API reference

Autocomplete in your IDE should work with the `bridge.lua` file, so you will see hints for `bridge.ads`, `bridge.payments`, `bridge.utils`, etc.

Available classes (from `bridge/bridge_classes`): `ads`, `analytics`, `leaderboards`, `payments`, `social`, `storage`, `user`, `utils`.

If you want to view the full API and annotations (for example `---@class leaderboards`), open the files in `bridge/bridge_classes`.

Payments note: on mobile devices only `payments.restore` may be available, while in Playgama/GamePush only `payments.get_purchases` may be available. Always check these methods for `nil` before calling them. Playgama and GamePush require calling `payments.get_purchases` at game start (after SDK initialization). On iOS (App Store) you should not call `payments.restore` at game start, only in response to a user action (for example, a "Restore purchases" button).

## Ads tuning

You can control when interstitial ads are allowed. By default, `INITIAL_DELAY = 100` and `INTERSTITIAL_COOLDOWN = 150`, so for the first 100 seconds `bridge.ads.is_interstitial_ads_available()` will always return `false`.

To adjust these values and to delay interstitial ads manually, use `require("bridge.ads_utils.ad_timer")`:

```lua
local ad_timer = require("bridge.ads_utils.ad_timer")
ad_timer.INITIAL_DELAY = 0
ad_timer.INTERSTITIAL_COOLDOWN = 60
ad_timer.delay_interstitial(30)
```

Rewarded ads also affect interstitial cooldown: it is reset to `INTERSTITIALL_COOLDOWN_DUE_REWARDED_AD` (default is equal to `INTERSTITIAL_COOLDOWN`).

You can also control whether sound is muted during ads (by changing the master group gain). By default it is enabled. To disable it:

```lua
local ad_sound_mute = require("bridge.ads_utils.ad_sound_mute")
ad_sound_mute.MUTE_SOUND_ON_ADS = false
```

## Recommended workflow: enable only the SDKs you need before a platform build

It is recommended to add only the SDK dependencies you need right before a platform build, and remove them after the build. Some SDKs may conflict with each other (for example, [Playgama SDK](https://github.com/KassiaL/playgama_sdk) and [GamePush](https://github.com/megalanthus/defold-gamepush/archive/master.zip)).

You can automate this with command-line tools, for example by using separate Git branches per platform, or by using scripts (Python, bash) that update `game.project` and your Lua initialization code.

Example build pipeline:

```bash
python3 platform_python_scripts/build_stage.py "$html5_vendor" start

java -jar "$bob" clean resolve --archive --platform js-web build bundle --bundle-output="$path_to_bundle" --liveupdate "$liveupdate" --variant release --texture-compression "yes" --build-report-html "${path_to_bundle}reports/report.html"

python3 platform_python_scripts/build_stage.py "$html5_vendor" finish
```

In this approach, on `start` you typically:

- add platform-specific dependencies into `game.project`
- update your Bridge init code to use one of:
  - `bridge.init_sdks({ bridge_playgama, bridge_mock })`
  - `bridge.init_sdks({ bridge_gamepush, bridge_mock })`
- update the corresponding requires in your Lua init script to include one of:
  - `local bridge_playgama = require("bridge.playgama")`
  - `local bridge_gamepush = require("bridge.gamepush")`

On `finish` you revert those changes (remove the dependencies from `game.project` and restore the init script) to keep the project clean and avoid SDK conflicts in other builds.

## Mock Usage for Testing

The mock can also be used for testing ads and other features. Example:

```lua
local offers_catalog = {}
for _, offer in pairs(offers.general_offers) do
    table.insert(offers_catalog, { ident = offer.id, price_string = "1.99 $", currency_code = "USD", title = "", description = "", price = 1.99 })
end
bridge_mock.set_payments_supported_true(offers_catalog)

bridge_mock.enable_social()
bridge_mock.enable_leaderboards()
bridge_mock.set_rewarded_ad_reward_enabled(true)
bridge_mock.delay_sdk_init(3)
```

This is useful for testing ads and other functionality without real SDKs.

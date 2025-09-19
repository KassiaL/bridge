# Bridge Extension for Defold

The `bridge` extension helps you work with multiple SDK plugins in Defold. Currently, it supports Playgama, Appodeal, Defold IAP, and Firebase. You can easily integrate and use these plugins by calling only the methods from `bridge.lua`.

> This extension is just a set of wrappers over SDKs to unify their usage. You are welcome to visit the [pull request page](https://github.com/KassiaL/bridge/pulls) and add your own wrappers, making it easy for everyone to use any existing SDK in a unified way.

## Supported SDKs

- Playgama
- Appodeal
- Defold IAP
- Firebase Analytics

## Setup

Open your `game.project` file and add the following line to the `dependencies` field under the `[project]` section:

```
https://github.com/KassiaL/bridge/archive/main.zip
```

## SDK Dependencies

Add the dependencies for the SDKs you want to use. Each SDK may require one or more dependencies:

### Playgama

[Playgama SDK](https://github.com/KassiaL/playgama_sdk)

```
https://github.com/KassiaL/playgama_sdk/archive/main.zip
```

[JSToDef](https://github.com/AGulev/jstodef)

```
https://github.com/AGulev/jstodef/archive/refs/tags/3.0.0.zip
```

### Appodeal

[Appodeal](https://github.com/KassiaL/appodeal)

```
https://github.com/KassiaL/appodeal/archive/master.zip
```

### Defold IAP

[Defold IAP](https://github.com/defold/extension-iap)

```
https://github.com/defold/extension-iap/archive/master.zip
```

### Firebase Analytics

[Firebase](https://github.com/defold/extension-firebase)

```
https://github.com/defold/extension-firebase/archive/master.zip
```

[Firebase Analytics](https://github.com/defold/extension-firebase-analytics)

```
https://github.com/defold/extension-firebase-analytics/archive/master.zip
```

## Integration Example

```lua
local bridge = require("bridge.bridge")
local bridge_mock = require("bridge.mock")
local bridge_firebase = require("bridge.firebase")
local bridge_playgama = require("bridge.playgama")
local bridge_appodeal = require("bridge.appodeal")
local defold_iap = require("bridge.defold_iap")

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

You can then use the universal method `run_after_sdk_init`, which calls your callback only after the SDKs are initialized:

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

## API Overview

Below are the available APIs from `bridge_classes`:

### ads

- is_reward_ads_available(): boolean
- is_interstitial_ads_available(): boolean
- show_reward_ads(reward_callback, close_callback, error_callback, opened_callback)
- show_interstitial_ads(close_callback, error_callback, opened_callback)

### analytics

- log_string(event, param, value)
- log_int(event, param, value)
- log(event)
- log_number(event, param, value)
- log_table(event, value)

### leaderboards

- get_type(): "not_available" | "in_game" | "native" | "native_popup"
- set_score(leaderboard_id, score)
- get_entries(leaderboard_id, callback) — works only when get_type() == "in_game"
- show_native_popup(leaderboard_id) — works only when get_type() == "native_popup"

### payments

- is_supported(): boolean
- set_callback(callback)
- purchase(id)
- consume(id)
- get_catalog(purchases_id_list, callback)
- restore()

### social

- is_share_supported(): boolean
- share(options, success_callback)
- is_invite_friends_supported(): boolean
- invite_friends(options, success_callback)
- is_add_to_favorites_supported(): boolean
- add_to_favorites(success_callback)
- is_add_to_home_screen_supported(): boolean
- add_to_home_screen(success_callback)
- is_rate_supported(): boolean
- rate(success_callback)

### storage

- is_supported(): boolean
- set(key, value)
- get(key, callback)
- set_multiple(keys_array, values_array)
- get_multiple(keys_array, callback)

### user

- is_authorization_supported(): boolean
- is_authorized(): boolean
- get_player_id(): string
- get_player_name(): string

### utils

- get_language(): string
- get_server_time(callback_millis)
- send_platform_message(message)
- get_platform_id(): string

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

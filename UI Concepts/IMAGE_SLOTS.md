# MileageTax — image slots

Every scene in the app checks Assets.xcassets for an image with the exact name below.
If the image is there, it's used (cropped to fill, with a slow zoom drift). If not, the drawn art shows instead.

**How to add one:** generate the image, then drag it into `MileageTax/Assets.xcassets` and rename the image set to the exact slot name. No code changes are needed.

**Shared style (put this at the start of every prompt):**
> Cinematic photoreal night/dusk photography, deep navy and teal palette, glowing electric-cyan (#19D8F5) light trails on the road, subtle emerald (#22E39A) accents, high dynamic range, crisp detail, moody atmospheric haze, no text, no logos, no people, no UI.

Keep the top ~25% and the bottom ~30% of portrait images calm and darker, because headlines and buttons sit there.

## Portrait backgrounds (9:16, 1290×2796 or 1080×1920)

| Slot name | Where it shows | Prompt (after the shared style) |
|---|---|---|
| `scene_splash` | Splash | Alpine lake at blue hour, snow-capped jagged peaks reflected in still water, pine forest shoreline, a winding road in the foreground glowing with cyan light trails sweeping toward the lake, stars appearing in a dark sky, warm amber glow on the horizon. |
| `scene_onboard_mile` | Onboarding 1 "Every mile means money" | Mountain highway at dusk beside a mirror lake, one modern dark car seen from behind with red tail lights, road edges outlined in glowing cyan light, snowy peaks, soft orange horizon. |
| `scene_onboard_gps` | Onboarding 2 "GPS so precise" | Top-down dark city map at night, as if from a satellite: dim teal street grid, a river, one bright glowing cyan-to-green route line snaking from bottom to top with a glowing pin at each end. |
| `scene_onboard_detect` | Onboarding 3 "Detects your drive" | Downtown skyline at night across a wide empty boulevard, warm and cyan window lights, a dark sedan seen from behind in the middle of the road, faint cyan signal rings rising above the car. |
| `scene_onboard_deduction` | Onboarding 4 "Never lose a deduction" | Calm mountain lake at twilight, symmetrical reflection, pine silhouettes, gentle cyan road glow along the shore, open dark space in the centre for an overlaid shield icon. |
| `scene_paywall` | Paywall header (only the top ~40% is visible) | Wide panoramic snowy mountain range at dawn above a lake, pastel blue-to-peach sky, calm, premium, lots of sky. |
| `scene_lock` | Face ID lock screen | Moody mountain lake at night under a starry sky, very dark and calm, minimal detail in the centre. |
| `scene_radar` | Radar tab | Winding mountain road at dusk viewed from a hillside, snow peaks, lake, cyan light-trail road curving into the distance. |
| `scene_classify` | Classify tab (top half) | City skyline and bridge at night from a hill, a road winding toward the city with cyan light trails, deep blue sky. |
| `scene_track` | Track tab (top 70%) | Coastal cliff highway at sunset, purple-orange sky, ocean on the right, a winding road with amber and cyan light trails. |
| `scene_vault` | Vault tab | Snowy alpine valley at night, frozen lake, very dark and secure feeling, faint cyan glow on the horizon. |
| `scene_rules` | Rules tab | Dawn over layered mountain ridges and mist, cool blue tones, soft light, calm. |

## Card banners (landscape 8:3, about 1600×600)

The subject should sit on the **right side**. The left 50% gets darkened for text.

| Slot name | Where it shows | Prompt (after the shared style) |
|---|---|---|
| `card_ytd` | Radar "YTD verified deduction" card | Panoramic mountain lake at dusk, horizon in the lower third, glowing cyan road on the right. |
| `card_vault` | Vault "Tax Deduction Vault" card | Snowy peaks reflected in a lake, a winding cyan road on the right side. |
| `card_workshift` | Rules "Work Shift Schedule" card | City-edge highway at blue hour with a glowing cyan clock-like light ring on the right. |
| `map_geofence` | Rules "Geofence" card | Dark top-down city map with a glowing cyan circular geofence ring on the right. |

## Map tiles (landscape, about 1600×800)

| Slot name | Where it shows | Prompt (after the shared style) |
|---|---|---|
| `map_live` | Radar "Live drive" card | Dark navy 3D city map at a slight tilt, teal street grid, one thick glowing cyan route line with a bright start dot. |
| `map_classify_route` | Classify trip card | Abstract dark topographic map with a glowing cyan route curving from left to right. |
| `map_thumb` | Trip thumbnails (square, 512×512) | Square dark map tile with a short glowing green route and two dots. |

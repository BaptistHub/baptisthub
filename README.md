# BaptistHub

A Flutter app for the preaching, documentaries and music on
[allthepreaching.com](https://allthepreaching.com).

## Download

**[Download the Android APK](https://github.com/BaptistHub/baptisthub/raw/main/app-release.apk)** (about 57 MB)

Open the file on your Android phone to install it. Android will ask you to allow installing apps
from your browser or file manager the first time.

## Features

- **Home**: a carousel of new sermons, Continue Watching, Latest, Most Watched, preachers, churches,
  documentaries, hymns, podcasts and soulwinning.
- **Sermons**: browse by preacher (each has Sermons and Clips tabs), by church, or by conference year.
- **Films**: a documentaries section laid out like Netflix. It has a billboard, a Top 10 row with large
  numerals, genre rows, a detail page with More Like This, and series pages with a season picker.
- **Music**: Hymns, Psalms and the FWBC Collection, with an album view, a background mini player and a
  Now Playing screen (shuffle, repeat, queue).
- **Player**: resumes where you stopped, offers "Listen instead" (plays the sermon's audio only), and
  shows an Up Next list.
- **Downloads**: save sermons (as video or audio only), films and songs, or whole albums, for offline playback.
  Downloads keep running in the background with a progress notification. Every tab has a Downloads button,
  which turns into a progress ring while anything is downloading.
- **Lock screen controls**: audio shows play/pause, skip and seek on the lock screen and in the notification,
  with artwork. Headset and car buttons work too (`just_audio_background`).
- **Library**: My List and watch history, stored on the device.

## Data source

The app reads the site's public JSON API at `https://api.allthepreaching.com`:

| Endpoint | Used for |
| --- | --- |
| `GET /api/videos?page=&sort=views` | Latest / most-watched feeds (24 per page) |
| `GET /api/categories` | Every preacher, church, album, podcast and series, with counts |
| `GET /api/categories/{slug}?page=&limit=` | A preacher's sermons, an album's tracks, and so on |
| `GET /api/videos/{id}/recommendations` | Up next / You may also like |
| `GET /api/search?q=&limit=&offset=` | Search |

Media files are served from `kjv1611only.com`. Video is `.mp4`, music is `.mp3`, and newer sermons
have an `.mp3` next to the `.mp4`. Thumbnails in the old `/images/thumbs/` folders no longer exist,
so the app draws its own poster and album artwork instead of showing broken images.

## Project layout

```
lib/
  core/      api client, models, catalog (groups categories into preachers,
             churches, albums...), audio controller, local library, navigation
  widgets/   generated artwork, cards, paged feed, mini player
  screens/   one file per screen
```

Curated content lives in `lib/core/catalog.dart`: the church list and which pastor leads each
church, display names for preachers, the music, podcast and series lists, and the documentary
genre keywords.

## Run

```bash
flutter pub get
flutter run            # Android / iOS device or emulator
flutter test           # unit tests + layout overflow sweep
```

`test/layout_test.dart` renders every screen with recorded API responses (`test/fixtures/`) at
320, 360 and 412 px wide, and at 1.3× text size, on Android. It fails if anything overflows and
names the widget responsible.

Android build: AGP 8.9.1, Gradle 8.11.1, compileSdk 36 (required by `background_downloader`) and minSdk 24
(required by `audio_session`). `MainActivity` extends `AudioServiceActivity`, which lock screen controls need.

The API does not send CORS headers, so the **web** build only works in a browser started with web
security turned off. Android and iOS are the intended targets.

## Image credits

The church images in `assets/churches/` are cropped copies of images the churches publish themselves:

| Church | Source |
| --- | --- |
| Faithful Word Baptist Church | ["Steven L Anderson preaching at his church in April 2017"](https://commons.wikimedia.org/wiki/File:Steven_L_Anderson_preaching_at_his_church_in_April_2017.jpg), Steven L. Anderson (Faithful Word Baptist Church), CC BY 3.0. The app shows this credit on the church page. |
| Stedfast Baptist Church | [stedfastkjv.com](https://stedfastkjv.com) |
| First Works Baptist Church | [fwbcla.org](https://www.fwbcla.org) |
| Sure Foundation Baptist Church | [surefoundationbaptist.com](https://www.surefoundationbaptist.com) |
| Anchor Baptist Church | Their logo, from the church's uploads on allthepreaching.com |
| Soulwinning Baptist Church Melbourne | [soulwinningbaptist.au](https://www.soulwinningbaptist.au) |

Get permission from each church before publishing the app to a store.

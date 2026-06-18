
# Bare Weather
A simple, interactive weather widget that minds its own business. For KDE Plasma.

## Showcase

**Card Layout**
- **Animated Icons** - All icons in header, day tabs, and hourly cards are animated (Can be toggled off) 
- **Color Coded headers** - Weather element headers are color coded with the conditions and synced to the hour as you scroll or drag through the timeline, or to the day as you switch day tabs.  
- **Daily Forecast** - Glance across the tabs and the icons give you the gist of the day's condition and temperature. Choose your starting hour between 12AM or 6AM when switching day tabs so the timeline opens closer to when you start the day.
- **Hourly cards** - Scroll or drag through the whole forecast, the day tabs keep pace.  Cards are color coded when there is snow, rain, or a mixture of both.

<video src="https://github.com/user-attachments/assets/8c8c85c7-979a-42c2-89fd-e033eaf67a3a" autoplay loop muted playsinline width="480"></video>






**Graph Layout**
- **Temperature Curve** - A quick glance over the next 12 hours forecast. The curve reshapes as you scroll or drag through the hour and day. 
- **Precipitation Curve** - A separate curve in blue representing the precipitation chance throughout the days. The curve also shows the precipitation amount when it detects it. The curve tints toward white when there is snow. 
- **Day Tabs** - Switching to a different day and the curve morphs to that day's shape. 
- **Timeline** - Pick how dense the curve is between displaying every hour or every 2 hours. 

<video src="https://github.com/user-attachments/assets/1d070035-6d91-4ac7-a4c4-236a39fd5fca" autoplay loop muted playsinline width="480"></video>




## Install

### KDE Store

Right-click your panel or desktop → **Add Widgets…** → **Get New Widgets** →
**Download New Plasma Widgets**, then search for **Bare Weather** and click
**Install**.

### From a release file

1. Download the latest version from the [Releases](https://github.com/bvlthvzvr/BareWeather/releases) page.
2. Install it — either:
   - **GUI:** Add Widgets… → Get New Widgets → **Install Widget from Local File…**, or
   - **Terminal:**
     ```bash
     kpackagetool6 --type Plasma/Applet --install bare-weather.plasmoid
     ```

### From source

```bash
git clone https://github.com/bvlthvzvr/BareWeather.git
cd BareWeather
kpackagetool6 --type Plasma/Applet --install .
```


### Update / remove

```bash
# update (after pulling a newer version)
kpackagetool6 --type Plasma/Applet --upgrade .

# remove
kpackagetool6 --type Plasma/Applet --remove org.bvlthvzvr.weather
```

## Privacy

Less is bare! This widget just tells you what the sky's up to.  **No account, no API key, nor does it offer other weather service options that requires one, and nothing the widget use to profile, or monetize where and who you are.** The widget use Open-Meteo as the only provider, KDE Public Alert for weather alerts, and Mullvad for auto detect location.  Location search runs through Open-Meteo,  same provider as the weather, so there's no extra third party needed. 

**Bare Weather under the hood**

| Service                                                                                                | Purpose                                                         | When                                                                                     |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Open-Meteo** (`api.open-meteo.com`)<br><br>**Open-Meteo geocoding** (`geocoding-api.open-meteo.com`) | the weather itself<br><br>turning a place name into coordinates | **always**, once you've set a location<br><br>**only** when you use the **Search** field |
| **KDE FOSS Public Alert Server** (`alerts.kde.org`)                                                    | severe-weather alerts (worldwide)                               | **only** if you turn *Weather alerts* on                                                 |
| **Mullvad** (`am.i.mullvad.net`)                                                                       | guessing your city from your IP                                 | **only** if you use *Auto-detect*                                                        |


**What's done to enhance privacy:**
- **Auto-detect and alerts are both off by default**. The widget makes no IP-geolocation call and no alert request at all until you use them.
- The only IP-geolocation provider is Mullvad, picked because it's a privacy
  company with a public no-logging stance.
- Alerts come from the KDE Public Alert Server. Rather than reaching out to each government agency in different countries, **KDE Public Alert aggregates hundreds of CAP feeds  worldwide into one place. So you get the alerts without having to contact or revealing yourself to every agency for alerts.** 
- **No map picker** as it requires dependency to use them.  And exposes your IP for something the auto detection and manual location lookup already handles.
- **Coordinates get rounded to about 1 km/.62mi (2 decimals)** on every weather and alert
  request, **even if you enter the exact coordinate**. 
- Open-Meteo needs no account or key and does no tracking. [Terms & Privacy](https://open-meteo.com/en/terms)


**Language**

Bare Weather is only in English for now, it would be wonderful to see it in yours! Translation is just about as easy as filling out a form. No coding required.
1. Download the template [`po/weather.pot`](https://github.com/bvlthvzvr/BareWeather/blob/main/po/weather.pot)
2. Rename it to your language , ex `de.po` for German, `fr.po` for French. Then fill in the translations. 
3. Send it back by Email or  [opening an issue](https://github.com/bvlthvzvr/BareWeather/issues/new) and attaching the file. Otherwise open PR. 

You'll be credited for your work!

## Credits

- Weather data from [Open-Meteo](https://open-meteo.com) (CC-BY 4.0).
- Icons derived from [Meteocons](https://github.com/basmilius/weather-icons) by
  Bas Milius (MIT). See `contents/icons/*/ATTRIBUTION.md` for details.
- Severe-weather alerts via the [KDE FOSS Public Alert Server](https://invent.kde.org/webapps/foss-public-alert-server)
  (AGPL), only when you enable alerts.
- Auto-detect via [Mullvad](https://mullvad.net), only when you
  use auto-detect.

## License

MIT — see [LICENSE](LICENSE).

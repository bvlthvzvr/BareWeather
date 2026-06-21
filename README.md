
# Bare Weather
A simple, interactive weather widget that minds its own business. For KDE Plasma.

## Showcase

**Card Layout**
- **Animated Icons** - All icons in header, day tabs, and hourly cards are animated (Can be toggled off) 
- **Color Coded headers** - Weather element headers are color coded with the conditions and synced to the hour as you scroll or drag through the timeline, or to the day as you switch day tabs.  
- **Daily Forecast** - Glance across the tabs and the icons give you the gist of the day's condition and temperature. Choose your starting hour between 12AM or 6AM when switching day tabs so the timeline opens closer to when you start the day.
- **Hourly cards** - Scroll or drag through the whole forecast, the day tabs keep pace.  Cards are color coded when there is snow, rain, or a mixture of both.

<img width="600" height="451" alt="untitled2" src="https://github.com/user-attachments/assets/2e3c201e-f139-47a4-a69b-d8afc05337c6" />







**Graph Layout**
- **Temperature Curve** - A quick glance over the next 12 hours forecast. The curve reshapes as you scroll or drag through the hour and day. 
- **Precipitation Curve** - A separate curve in blue representing the precipitation chance throughout the days. The curve also shows the precipitation amount when it detects it. The curve tints toward white when there is snow. 
- **Day Tabs** - Switching to a different day and the curve morphs to that day's shape. 
- **Timeline** - Pick how dense the curve is between displaying every hour or every 2 hours. 
<img width="600" height="352" alt="untitled" src="https://github.com/user-attachments/assets/a13a3c25-562a-436a-8d5f-eda71c840548" />





## Privacy

Pared to the bare necessities. **No account, no API key, nor does it offer other weather service options that requires one, and nothing the widget use to profile, or monetize where and who you are.** The widget use Open-Meteo as the only provider, KDE Public Alert for weather alerts, and Mullvad for auto detect location.  Location search runs through Open-Meteo,  same provider as the weather, so there's no extra third party needed. 

**Bare Weather under the hood**

| Service                                                                                                | Purpose                                                         | When                                                                                     |
| ------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **Open-Meteo** (`api.open-meteo.com`)<br><br>**Open-Meteo geocoding** (`geocoding-api.open-meteo.com`) | the weather itself<br><br>turning a place name into coordinates | **always**, once you've set a location<br><br>**only** when you use the **Search** field |
| **KDE FOSS Public Alert Server** (`alerts.kde.org`)                                                    | severe-weather alerts (worldwide)                               | **only** if you turn *Weather alerts* on                                                 |
| **Mullvad** (`am.i.mullvad.net`)                                                                       | guessing your location from your IP                                 | **only** if you use *Auto-detect*                                                        |


**What's done to enhance privacy:**
- **Auto-detect and alerts are both off by default**. The widget makes no IP-geolocation call and no alert request at all until you use them.
- The only IP-geolocation provider is Mullvad, picked because it's a privacy
  company with a public no-logging stance.
- Weather alerts come from KDE Public Alert Server, a free and open-source aggregator. **It collects official severe weather warnings in standard CAP format from agencies around the world into one place, so you get worldwide alerts without ever contacting, or exposing yourself to, each individual agency.**
- **No map picker** as it requires dependency to use them.  And exposes your IP to something the auto detection and manual location lookup already handles.
- **Coordinates get rounded to about 1 km/.62mi (2 decimals)** on every weather and alert
  request, **even if you enter the exact coordinate**. 
- Open-Meteo needs no account or key and does no tracking. [Terms & Privacy](https://open-meteo.com/en/terms)


## Language

Bare Weather is only in English for now, it would be wonderful to see it in yours! Translation is just about as easy as filling out a form. No coding required.
1. Download the template [`po/weather.pot`](https://github.com/bvlthvzvr/BareWeather/blob/main/po/weather.pot)
2. Rename it to your language , ex `de.po` for German, `fr.po` for French. Then fill in the translations. 
3. Send it back by [Email](mailto:bareweather.recreate814@silomails.com) or by [opening an issue](https://github.com/bvlthvzvr/BareWeather/issues/new) and attaching the file. Otherwise Open PR.

You'll be credited for your work!


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

## Credits

- Card layout is inspired by [Advanced Weather Widget](https://github.com/pnedyalkov91/advanced-weather-widget)
- Weather data from [Open-Meteo](https://open-meteo.com) (CC-BY 4.0).
- Icons derived from [Meteocons](https://github.com/basmilius/weather-icons) by
  Bas Milius (MIT). See `contents/icons/*/ATTRIBUTION.md` for details.
- Severe-weather alerts via the [KDE FOSS Public Alert Server](https://invent.kde.org/webapps/foss-public-alert-server) (AGPL).
- Auto-detect via [Mullvad](https://mullvad.net)

## License

MIT — see [LICENSE](LICENSE).
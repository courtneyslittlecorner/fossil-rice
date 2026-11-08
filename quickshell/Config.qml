pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    //*=======================================================================*/
    // READ THIS NOTE:
    // Simply add to this list in order to create your
    // own color schemes, they will automatically show up in the theme picker.
    property var colors: themes[themes[settings.currentTheme] == null ? 'helios' : settings.currentTheme]
    property var themes: {
        "helios": {
            "base": "#181818",
            "shadow": "#121212",
            "highlight": "#333333",
            "urgent": "#ff723e",
            "accent": "#fccf8a",
            "accentDark": "#87704f",
            "text": "#121212",
            "textLight": "#d0daed",
            "outline": "#121212",
            "outlineGradientFade": "#161616",
            "defaultWallpaperPath": "",
            "danger": "#fc5870",
            "warning": "#fcd37b",
            "cbodyBackground": "#fccf8a",
            "cbodyBackgroundShadow": "#d1a67b",
            "cbodyMoonBackground": "#484a5e",
            "cbodyMoonBackgroundShadow": "#5e5e5e",
            "cbodyStroke": "#000000",
            "cbodyPowerMenu": "#fccf8a",
            "cbodyThemingMenu": "#a0675d",
            "cbodyFavoriteApps": "#5e5e5e",
            "cbodyMainMenu": "#666c93",
            "glassTintColor": "#fce2ab",
            "appLauncherBackground": "#252525",
            "patternLineColor": "#87704f",
            "humorWet": "#425682",
            "humorDry": "#c4a78f",
            "humorCold": "#92bbcc",
            "humorHot": "#c44444",
            "elementAir": "#ccdde2",
            "elementWater": "#6f8ebc",
            "elementEarth": "#473e39",
            "elementFire": "#c15555"
        },
        "eris": {
            "base": "#1b1c1e",
            "shadow": "#121212",
            "highlight": "#2f2f33",
            "urgent": "#ff723e",
            "accent": "#c7cfe5",
            "accentDark": "#989daa",
            "text": "#121212",
            "textLight": "#b6aae2",
            "outline": "#121212",
            "danger": "#fc5870",
            "warning": "#fcd37b",
            "cbodyBackground": "#d2dddc",
            "cbodyBackgroundShadow": "#97a09f",
            "cbodyMoonBackground": "#484a5e",
            "cbodyMoonBackgroundShadow": "#5e5e5e",
            "cbodyStroke": "#000000",
            "cbodyPowerMenu": "#d2dddc",
            "cbodyThemingMenu": "#767d7f",
            "cbodyFavoriteApps": "#536868",
            "cbodyMainMenu": "#68877f",
            "glassTintColor": "#b9c5c9",
            "appLauncherBackground": "#252525",
            "patternLineColor": "#505160",
            "humorWet": "#425682",
            "humorDry": "#c4a78f",
            "humorCold": "#92bbcc",
            "humorHot": "#c44444",
            "elementAir": "#ccdde2",
            "elementWater": "#6f8ebc",
            "elementEarth": "#473e39",
            "elementFire": "#c15555"
        },
        "priapus": {
            "base": "#1f211e",
            "shadow": "#121410",
            "highlight": "#393d2d",
            "urgent": "#ff723e",
            "accent": "#a7b777",
            "accentDark": "#747c5c",
            "text": "#121212",
            "textLight": "#d0daed",
            "outline": "#141612",
            "danger": "#fc5870",
            "warning": "#fcd37b",
            "cbodyBackground": "#f2efb3",
            "cbodyBackgroundShadow": "#aaa87c",
            "cbodyMoonBackground": "#484a5e",
            "cbodyMoonBackgroundShadow": "#5e5e5e",
            "cbodyStroke": "#000000",
            "cbodyPowerMenu": "#f2d793",
            "cbodyThemingMenu": "#666c75",
            "cbodyFavoriteApps": "#5b5050",
            "cbodyMainMenu": "#5b6b54",
            "glassTintColor": "#a6bf85",
            "appLauncherBackground": "#252525",
            "patternLineColor": "#4a5437",
            "humorWet": "#425682",
            "humorDry": "#cdce8c",
            "humorCold": "#bcd8d6",
            "humorHot": "#c44444",
            "elementAir": "#c7e0ca",
            "elementWater": "#6f8ebc",
            "elementEarth": "#3e3f2f",
            "elementFire": "#c15555"
        },
        "eros": {
            "base": "#15101c",
            "shadow": "#110c16",
            "highlight": "#2c243d",
            "urgent": "#ff723e",
            "accent": "#fccb7b",
            "accentDark": "#87704f",
            "text": "#121212",
            "textLight": "#d0daed",
            "outline": "#0c0b0c",
            "danger": "#eda1a6",
            "warning": "#fcd37b",
            "cbodyBackground": "#f9997f",
            "cbodyBackgroundShadow": "#b78487",
            "cbodyMoonBackground": "#484a5e",
            "cbodyMoonBackgroundShadow": "#5e5e5e",
            "cbodyStroke": "#000000",
            "cbodyPowerMenu": "#f9997f",
            "cbodyThemingMenu": "#705a7a",
            "cbodyFavoriteApps": "#ad7082",
            "cbodyMainMenu": "#53475e",
            "glassTintColor": "#3c2d66",
            "appLauncherBackground": "#252525",
            "patternLineColor": "#725c3b",
            "humorWet": "#425682",
            "humorDry": "#c4a78f",
            "humorCold": "#92bbcc",
            "humorHot": "#c44444",
            "elementAir": "#ccdde2",
            "elementWater": "#6f8ebc",
            "elementEarth": "#473e39",
            "elementFire": "#c15555"
        },
        "hades": {
            "base": "#181818",
            "shadow": "#121212",
            "highlight": "#333333",
            "urgent": "#ff723e",
            "accent": "#d1ceca",
            "accentDark": "#969593",
            "text": "#eaeaea",
            "textLight": "#f7f8f9",
            "outline": "#e3e7e8",
            "danger": "#aa3a3a",
            "warning": "#c6c479",
            "cbodyBackground": "#181818",
            "cbodyBackgroundShadow": "#121212",
            "cbodyMoonBackground": "#484a5e",
            "cbodyMoonBackgroundShadow": "#5e5e5e",
            "cbodyStroke": "#eaeaea",
            "cbodyPowerMenu": "#181818",
            "cbodyThemingMenu": "#181818",
            "cbodyFavoriteApps": "#181818",
            "cbodyMainMenu": "#181818",
            "glassTintColor": "#d7dddb",
            "appLauncherBackground": "#252525",
            "patternLineColor": "#7f7f7f",
            "humorWet": "#425682",
            "humorDry": "#c6c479",
            "humorCold": "#8da5c9",
            "humorHot": "#c44444",
            "elementAir": "#cccccc",
            "elementWater": "#66929e",
            "elementEarth": "#423f3d",
            "elementFire": "#c15555"
        }
    }

    enum SystemPopup {
        Startmenu,
        ThemePicker,
        AppLauncher,
        None
    }
    enum SidebarPopup {
        PowerMenu,
        FavoriteAppsMenu,
        ThemingMenu,
        MainMenu,
        None
    }
    // TODO: Finish adding all the other widgets
    readonly property var widgetTypes: ["Weather", "Clock", "QuestBoard", "Hotkeys", "PhotoFrame", "Battery", "Brightness", "SunTracker"]
    readonly property var widgetPaths: {
        "Weather": "WeatherWidget.qml",
        "Clock": "ClockWidget.qml",
        "QuestBoard": "QuestBoardWidget.qml",
        "Hotkeys": "HotkeysWidget.qml",
        "PhotoFrame": "PhotoFrameWidget.qml",
        "Battery": "BatteryWidget.qml",
        "Brightness": "BrightnessWidget.qml",
        "SunTracker": "SunTrackerWidget.qml"
        //"CPUTemp": "CPUTemperatureWidget.qml",
        //"GPUTemp": "GPUTemperatureWidget.qml",
        //"RAM": "RAMWidget.qml",
        //"TheDate": "DateWidget.qml"
    }

    // Weather stuff
    property var weatherData: undefined
    function fetchWeatherData() {
        if (!settings.openWeatherMap.enableWeather) {
            return;
        }
        // No key yet: go straight to the keyless backup provider.
        if (!settings.openWeatherMap.apiKey) {
            fetchOpenMeteo();
            return;
        }
        var xmlhttp = new XMLHttpRequest();
        xmlhttp.onreadystatechange = function () {
            if (xmlhttp.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            if (xmlhttp.status == 200) {
                try {
                    weatherData = JSON.parse(xmlhttp.responseText);
                    return;
                } catch (e) {
                    console.warn("Weather: got an unparsable response from openweathermap: " + e);
                }
            } else {
                console.warn("Weather: openweathermap request failed with status " + xmlhttp.status + " - falling back to Open-Meteo.");
            }
            // OpenWeatherMap failed (e.g. key not activated yet): use Open-Meteo instead.
            fetchOpenMeteo();
        };

        // encodeURIComponent so city names with spaces or special characters work (e.g. "São Paulo").
        const url = `https://api.openweathermap.org/data/2.5/weather` + `?q=${encodeURIComponent(settings.openWeatherMap.city)}` + `&appid=${settings.openWeatherMap.apiKey}` + `&units=metric` + `&lang=en`;

        xmlhttp.open("GET", url, true);
        xmlhttp.send();
    }

    // Backup provider: Open-Meteo needs no API key. Its answer is converted into the
    // same shape OpenWeatherMap returns, so the widget doesn't need to know the difference.
    function wmoCodeToMain(code) {
        if (code === 0) return "Clear";
        if (code <= 3) return "Clouds";
        if (code === 45 || code === 48) return "Atmosphere";
        if (code >= 51 && code <= 57) return "Drizzle";
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return "Rain";
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return "Snow";
        if (code >= 95) return "Thunderstorm";
        return "Clear";
    }
    function fetchOpenMeteo() {
        var parts = settings.openWeatherMap.city.split(",");
        var name = parts[0].trim();
        var country = parts.length > 1 ? parts[parts.length - 1].trim() : "";
        var geoUrl = "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name) + (country.length === 2 ? "&countryCode=" + country : "");
        var geo = new XMLHttpRequest();
        geo.onreadystatechange = function () {
            if (geo.readyState !== XMLHttpRequest.DONE) {
                return;
            }
            var place;
            try {
                place = JSON.parse(geo.responseText).results[0];
            } catch (e) {}
            if (geo.status != 200 || !place) {
                console.warn("Weather: Open-Meteo couldn't find the city \"" + settings.openWeatherMap.city + "\".");
                return;
            }
            var wx = new XMLHttpRequest();
            wx.onreadystatechange = function () {
                if (wx.readyState !== XMLHttpRequest.DONE) {
                    return;
                }
                try {
                    var cur = JSON.parse(wx.responseText).current;
                    weatherData = {
                        "name": place.name,
                        "weather": [{ "main": wmoCodeToMain(cur.weather_code) }],
                        "main": { "temp": cur.temperature_2m },
                        "clouds": { "all": cur.cloud_cover },
                        "source": "open-meteo"
                    };
                    console.log("Weather: updated from Open-Meteo for " + place.name + ": " + cur.temperature_2m + "°C, " + weatherData.weather[0].main);
                } catch (e) {
                    console.warn("Weather: Open-Meteo request failed with status " + wx.status);
                }
            };
            wx.open("GET", "https://api.open-meteo.com/v1/forecast?latitude=" + place.latitude + "&longitude=" + place.longitude + "&current=temperature_2m,weather_code,cloud_cover", true);
            wx.send();
        };
        geo.open("GET", geoUrl, true);
        geo.send();
    }
    Timer {
        interval: 10 * 60 * 1000
        running: Config.settings.openWeatherMap.enableWeather
        repeat: Config.settings.openWeatherMap.enableWeather
        triggeredOnStart: Config.settings.openWeatherMap.enableWeather
        onTriggered: Config.fetchWeatherData()
    }
    // Re-fetch shortly after the API key or city is edited in settings, instead of
    // waiting up to 10 minutes for the next timer tick.
    Timer {
        id: weatherRefetchDebounce
        interval: 1500
        onTriggered: Config.fetchWeatherData()
    }
    function scheduleWeatherRefetch() {
        weatherRefetchDebounce.restart();
    }

    function toggleFavoriteApp(appName: string, exec: list<string>, iconPath: string) {
        let updated = Object.assign({}, favoriteApps);
        if (favoriteApps[appName] != null) {
            delete favoriteApps[appName];
            return;
        }
        if (!favoriteApps[appName]) {
            updated[appName] = {};
            favoriteApps = updated;
        }
        updated[appName] = {
            "name": appName,
            "execCommand": exec,
            "icon": iconPath
        };
        favoriteApps = updated;
    }
    property alias favoriteApps: favoriteAppsAdapter.apps
    FileView {
        path: Qt.resolvedUrl("./favoriteapps.json")
        // when changes are made on disk, reload the file's content
        watchChanges: true
        onFileChanged: reload()
        // when changes are made to properties in the adapter, save them
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }
        JsonAdapter {
            id: favoriteAppsAdapter

            // IGNORE WARNING, do not wrap in ()
            property var apps: ({})
        }
    }
    //Widgets
    function addWidget(monitorName: string, widgetType: int, widgetName: string, x: int, y: int, enableBackground: bool) {
        let updated = Object.assign({}, widgets);
        if (!widgets[monitorName]) {
            updated[monitorName] = {};
            widgets = updated;
        }
        updated[monitorName] = Object.assign({}, updated[monitorName]);
        updated[monitorName][Object.keys(updated[monitorName]).length] = {
            "widgetName": widgetName,
            "widgetType": widgetType,
            "x": x,
            "y": y,
            "enableBackground": enableBackground,
            "monitorName": monitorName,
            "widgetId": Object.keys(updated[monitorName]).length.toString()
        };
        widgets = updated;
    }
    function updateWidget(monitorName: string, widgetId: int, widgetName: string, x: int, y: int, enableBackground: bool, widgetType: int) {
        let updated = Object.assign({}, widgets);
        if (!widgets[monitorName]) {
            console.error("Monitor not found!");
            return;
        }
        updated[monitorName] = Object.assign({}, updated[monitorName]);
        updated[monitorName][widgetId] = {
            "widgetName": widgetName,
            "widgetType": widgetType,
            "x": x,
            "y": y,
            "enableBackground": enableBackground,
            "monitorName": monitorName,
            "widgetId": widgetId
        };
        widgets = updated;
    }
    function removeWidget(monitorName: string, widgetId: string) {
        let updated = Object.assign({}, widgets);
        delete updated[monitorName][widgetId];
        widgets = updated;
    }
    property alias widgets: widgetsAdapter.monitors
    FileView {
        path: Qt.resolvedUrl("./widgets.json")
        // when changes are made on disk, reload the file's content
        watchChanges: true
        onFileChanged: reload()
        // when changes are made to properties in the adapter, save them
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }
        JsonAdapter {
            id: widgetsAdapter

            // IGNORE WARNING, do not wrap in ()
            property var monitors: ({})
        }
    }

    property bool openSettingsWindow: false
    property alias settings: settingsJsonAdapter.settings
    FileView {
        path: Qt.resolvedUrl("./settings.json")
        // when changes are made on disk, reload the file's content
        watchChanges: true
        onFileChanged: reload()
        // when changes are made to properties in the adapter, save them
        onAdapterUpdated: writeAdapter()

        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: settingsJsonAdapter
            property JsonObject settings: JsonObject {
                property string version: "0.1"
                property bool militaryTimeClockFormat: true
                property string currentTheme: "helios"
                property int defaultWindowRadius: 12
                property bool appLauncherBackground: true
                property JsonObject openWeatherMap: JsonObject {
                    property string apiKey: ""
                    property string city: "Umeå"
                    property string unit: "metric" //standard = kelvin, metric = c, imperial = F
                    property bool enableWeather: false
                }
                property JsonObject execCommands: JsonObject {
                    property string terminal: "kitty"
                    property string files: "nemo"
                }
                property JsonObject bar: JsonObject {
                    property int fontSize: 12
                    property double workspacePadding: 0.032
                    property int trayIconSize: 12
                    property bool monochromeTrayIcons: true
                }
                onCurrentThemeChanged: {
                    console.info("Updated theme to: " + currentTheme);
                    // Match the mouse cursor + window borders (see ~/.config/hypr/theme-sync.sh)
                    const name = root.themes[currentTheme] == null ? "helios" : currentTheme;
                    const t = root.themes[name];
                    Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/theme-sync.sh", name, String(t.base), String(t.accent), String(t.highlight)]);
                }
            }
        }
    }
}

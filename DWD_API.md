# DWD API

Base URL: `https://dwd.api.proxy.bund.dev/v30` or `https://app-prod-ws.warnwetter.de/v30`

Documentation: https://dwd.api.bund.dev/

## Most relevant endpoint: `/stationOverviewExtended?stationIds=`

stationIds have to be parsed from https://www.dwd.de/DE/leistungen/klimadatendeutschland/statliste/statlex_html.html?view=nasPublication&nn=16102 - however, the endpoint expects the value of "Stationskennung", not "Stations_ID", because *obviously*. Only stations with "Kennung"="MN" seem to provide forecasts (not every one though). "MN"-stations are stations with automated measurings every 10 minutes (however they usually don't return values in 10 minute resolution, but rather hourly). 

This list might be better to parse, it also includes international cities all over the world: https://www.dwd.de/DE/leistungen/met_verfahren_mosmix/mosmix_stationskatalog.cfg?view=nasPublication&nn=16102 
Here stationsId = ID. Most of the stations in Germany seem to work, however many outside of Germany return nothing or deny access.

Response looks like this:

```
{
    Stationskennung: {
        "forecast1": {
            "stationId": *(String)* Stationskennung,
            "start": *(Int)* start time of this forecast in Unix Time (meaning in milliseconds since 1.1.1970 00:00). Should be midnight/00:00 of the current day (has to be adjusted to timezone),
            "timestep": *(Int)* time between the listed measurings in milliseconds. usually 3600000 ms = 1h,
            "temperature": [*(Int)* list of temperature values in 10*Celsius, meaning 24 = 2.4 degrees Celcius, 250 = 25 degrees Celcius, etc.],
            "windSpeed": null most of the time,
            "windDirection": null most of the time,
            "windGust": null most of the time,
            "precipitationTotal": [*(Int)* list of precipitation values throughout the day, probably in 10*mm],
            "sunshine": [*(Int)* list of sunshine values, in 10*minutes, meaning 250 = 25 minutes, 410 = 41 minutes],
            "dewPoint2m": [*(Int)* list of dew point temperatures throughout the day, also in 10s],
            "surfacePressure": [*(Int)* list of surface pressure values in 10*mbar],
            "humidity": [*(Int)* list of humidity values in 10*percent, meaning 801 = 80.1%],
            "isDay": [*(Bool)* boolean values if sun is up or down],
            "cloudCoverTotal": [empty most of the time],
            "icon": [*(Int)* icon mapping values throughout the day, see icon map below],
            "precipitationProbablity": null most of the time,
            "precipitationProbablityIndex": null most of the time
        }
        "days": [
            {
                "dayDate": *(String)* date as string, like "2025-11-20", starts with the current day,
                "temperatureMin": *(Int)* min. temperature of the day in 10*Celsius,
                "temperatureMax": *(Int)* max. temperature of the day in 10*Celcius,
                "precipitation": *(Int)* precipitation, probably in 10*mm,
                "windSpeed": *(Int)* (highest?) wind speed in 10*km/h,
                "windGust": *(Int)* (highest?) wind gust speed in 10*km/h,
                "windDirection": *(Int)* (average?) wind direction in 10*degrees (3060 = 306),
                "sunshine": *(Int)* sunshine in 10*minutes,
                "sunrise": *(Int)* unix timestamp of sunrise,
                "sunset": *(Int)* unix timestamp of sunset,
                "moonrise": *(Int)* unix timestamp of moonrise,
                "moonset": *(Int)* unix timestamp of moonset,
                "moonriseOnThisDay": *(Int)* idk the difference to moonrise,
                "moonsetOnThisDay": *(Int)* idk the difference to moonset,
                "sunriseOnThisDay": *(Int)* idk the difference to sunrise,
                "sunsetOnThisDay": *(Int)* idk the difference to sunset,
                "moonPhase": *(Int)* numerical moon phase value i haven't figured out yet,
                "icon": *(Int)* icon for the day, see icon map below,
                "icon1": null most of the time,
                "icon2": null most of the time
            },
            {
                usually the 7 days of the following week
            }
        ]
        "forecast2": {
            another forecast which might have slightly different values, but is missing temperature values most of the time.
        }
        "warnings": [
            {
                "warnId": *(String)* id of the warning,
                "type": *(Int)* numerical category i haven't figured out yet,
                "level": *(Int)* numerical category i haven't figured out yet,
                "start": *(Int)* unix timestamp of start time,
                "end": *(Int)* unix timestamp of end time,
                "bn": *(Bool)* boolean value i don't know the meaning of,
                "description": *(String)* text description in german like "Es tritt leichter Frost zwischen 0 °C und -3 °C auf.",
                "event": *(String)* category like "FROST",
                "headline": *(String)* text headline like "Amtliche WARNUNG vor FROST",
                "instruction": *(String)* advised instructions like "Hinweis auf: mögliche Frostschäden. Handlungsempfehlungen: ggf. Frostschutzmaßnahmen ergreifen",
                "instructionHtml": *(String)* same instructions in HTML format,
            },
            {
                ...
            }
        ],
        "threeHourSummaries": null most of the time
    }

}
```

we can get a detailed day forecast here, also the weeks forecast, however, the days are not that detailed. the hourly values usually exceed the 24 hour mark though, so there are hourly forecast for the next one or two days.

# DWD Warnwetter API

there are other available endpoints under the base URL `https://s3.eu-central-1.amazonaws.com/app-prod-static.warnwetter.de/v16` 

Documentation: https://listed.to/@DieSieben/7851/api-des-deutschen-wetterdienstes

However, some requests can result in an "access denied" response at many endpoints and sometimes for specific stations

## most relevant enpoint: `/current_measurement_%s.json`

%s has to be replaced with the station id. this returns the current measurings of a station (no forecast)

Response looks like this:
```
{
    "precipitation3h": *(Int)* precipitation over the last 3h, probably in 10*mm,
    "totalsnow": *(Int)* snow, probably in 10*cm,
    "dewpoint": *(Int)* current dewpoint in 10*Celcius,
    "sunshine": *(Int)* sunshine for current hour in 10*minutes,
    "cloud_cover_total": *(Int)* cloud cover measure unsure, maybe 10*Okta, maybe percent,
    "icon": *(Int)* numerical value for current icon, see icon map below,
    "pressure": *(Int)* current pressure in 10*mbar,
    "meanwind": *(Int)* mean wind speed in 10*km/h,
    "maxwind": *(Int)* max wind speed in 10*km/h,
    "winddirection": *(Int)* current wind direction in 10*degrees,
    "precipitation": *(Int)* current precipitation, probably in 10*mm,
    "temperature": *(Int)* current temperature in 10*degrees,
    "humidity": *(Int)* current humidity in 10*percent,
    "time": *(Int)* unix timestamp of time of measurement,
    "history": [
        *history of every field, starting a few days back. probably not relevant for us. looks like this though:*
        field (like "temperature"): {
            "start": *(Int)* unix timestamp of start time,
            "timestep": *(Int)* timestep in ms,
            "data": [*(Int)* list of values every timestep]
        }
    ]


}
```

we can get the actual current weather data from here

## other forecast option `/forecast_mosmix_%s.json`

this one has less details than `/stationOverviewExtended`, and doesn't go as far into the futre, but it actually has values for wind forecasts

Response looks like this

```
{
    "forecast": {
        "start": *(Int)* unix timestamp of start time, usually midnight of the current day,
        "temperature": [*(Int)* list of temperatures in 10*Celsius, timestep is not specified but most probably 3600000 ms = 1h],
        "windDirection": [*(Int)* list of wind direction values in 10*degrees],
        "windGust": [*(Int)* list of wind gust speeds in 10*km/h],
        "windSpeed": [*(Int)* list of wind speeds in 10*km/h],
        "icon": [*(Int)* list of icon values, see icon map below],
        "precipitationTotal": [*(Int)* list of precipitation values, probably in mm]
    },
    "trend": {
        this looks the same, but "start" is 4 days in the future for some reason. hoever it has the fields
        "precipitationProbabilityHigh" and "precipitationProbabilityLow" with values ranging from 0 to presumably 1000, but i don't really know what they mean yet. this i followed by a "days" field with a list of forecasts for the next 4 days, starting at the current day, looking exactly the same as in /stationOverviewExtended
    }
    
}
```

# Icon Map

according to https://listed.to/@DieSieben/7851/api-des-deutschen-wetterdienstes, following IDs correspond to following weather types:

| icon id | weather |
| ------- | ------- |
| 1 | sunny |
| 2 | sunny, partly/slightly cloudy |
| 3 | sunny, cloudy |
| 4 | clouds |
| 5 | fog | 
| 6 | fog, slippery |
| 7 | light rain | 
| 8 | rain |
| 9 | heavy rain |
| 10 | slight rain, slippery |
| 11 | heavy rain, slippery |
| 12 | rain, occasional snowfall |
| 13 | rain, increased snowfall |
| 14 | light snowfall |
| 15 | snowfall |
| 16 | heavy snowfall |
| 17 | clouds, (hail) |
| 18 | sunny, light rain |
| 19 | sunny, heavy rain |
| 20 | sun, rain, occasional snowfall |
| 21 | sun, rain, increased snowfall |
| 22 | sunny, occasional snowfall |
| 23 | sunny, increased snowfall |
| 24 | sunny, (hail) |
| 25 | sunny, (heavy hail) |
| 26 | thunderstorm |
| 27 | thunderstorm, rain |
| 28 | thunderstorm, heavy rain |
| 29 | thunderstorm, (hail) |
| 30 | thunderstorm, (heavy hail) |
| 31 | (wind) |


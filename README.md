# GPS Viewer

GPS Viewer is an EdgeTX app for the Radiomaster TX16S transmitter that lets users plot logged flight telemetry data with respect to location on a map.  This is especially useful for identifying areas with poor radio transmission signal quality. 

![screenshot](images/screenshot_points.png)

It's also useful for assessing flight path consistency over multiple laps and verifying that the aircraft remains within the desired air space.

![screenshot](images/screenshot_curve.png)

GPS Viewer is a modification of [Log Viewer](https://github.com/offer-shmuely/edgetx-x10-scripts/wiki/LogViewer), which is for plotting telemetry with respect to time.

## Installation

Copy the `SCRIPTS` directory to your transmitter.

Optionally copy the `LOGS` directory to your transmitter if you'd like to have a sample log file with which to try out the app.

## Use

To open the app, press the system button on your transmitter and select the GPS Viewer app.

To move forward and backward between screens, use the next and previous page buttons on your transmitter.

To exit the app, press and hold the return button on your transmitter.

## Satellite Image

For flights at your local airfield, you can either use the included blank map or add a 480x272 satellite image of your airfield to the `SCRIPTS/TOOLS/gpsViewer` directory and update the following part of [lib_config.lua](SCRIPTS/TOOLS/gpsViewer/lib_config.lua) accordingly.  You'll need to specify the maximum and minimum longitude and latitude coordinates of your image.

```lua
M.maps = {
    {
      name = "ARCA small",
      image = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/arca_small.png"),
      long_min = -97.6074,
      long_max = -97.5984,
      lat_min = 30.3223,
      lat_max = 30.3267
    },
    {
      name = "ARCA large",
      image = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/arca_large.png"),
      long_min = -97.6179,
      long_max = -97.5870,
      lat_min = 30.3154,
      lat_max = 30.3306
    },
    {
      -- plot flights at any location on a dark green background
      name = "Blank",
      image = nil,
      long_min = nil,
      long_max = nil,
      lat_min = nil,
      lat_max = nil
    },
}
```

## Log File Requirements

For the app to function, the logged flight data must have a "GPS" column with latitude and longitude values separated by a space.  See the sample log file [SampleLog-2024-10-10-113001.csv](LOGS/SampleLog-2024-10-10-113001.csv).

To exclude test fights and keep load times reasonable, log files are ignored if they
- are over 2 MB,
- have less then 60 seconds of data,
- or don't have a GPS column.

These limits can be customized by editing [lib_config.lua](SCRIPTS/TOOLS/gpsViewer/lib_config.lua).
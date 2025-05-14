# GPS Viewer

GPS Viewer is an EdgeTX app for the Radiomaster TX16S transmitter that lets users plot logged flight telemetry data with respect to location on a map.  This is especially useful for identifying areas with poor radio transmission signal quality.

![screenshot](images/screenshot_points.png)

It can also be used to
- tune radio antenna alignment,
- assess GPS data accuracy before using it for autonomous flight,
- assess flight path consistency over multiple laps for racing and aerobatic competitions, and
- verify that the aircraft remains within the desired airspace.

Special thanks to Lee from the Painless360 Youtube channel for covering some of these use cases in more detail in the video below.

[![Painless360 Youtube Review Video](images/review_video_thumbnail.jpg)](https://www.youtube.com/watch?v=e8nbd5bs0Eg)

GPS Viewer is based on [Log Viewer](https://github.com/offer-shmuely/edgetx-x10-scripts/wiki/LogViewer) by Offer Shmuely, which is for plotting telemetry with respect to time.

## Installation

Copy the `SCRIPTS` directory to your transmitter.

Optionally copy the `LOGS` directory to your transmitter if you'd like to have a sample log file with which to try out the app.

## Use

To open the app, press the system button on your transmitter and select GPS Viewer.

1. Select log files to index.  This step determines which fields have data that changes over time and takes about one minute per MB.  Invalid log files are ignored as described in the [Log File Requirements](#log-file-requirements) section below.

    ![screenshot](images/step_01.png)

2. Select a log file from the index.

    ![screenshot](images/step_02.png)

3. Select fields to plot, a map to plot on, and the granularity.  Fields with data that doesn't change over time are excluded.  For large log files, it is recommended to use a low granularity.  This will plot fewer data points and make the sticks more responsive in step 4 below.

    ![screenshot](images/step_03.png)

4. View the plot.  You can use the control sticks to select a subinterval of the timeline to plot and inspect individual data points.

    - elevator stick: zoom timeline
    - aileron stick: pan timeline
    - rudder stick: move crosshair
    - scroll wheel: fine tune crosshair
    - scroll button: toggle plot style
    - telemetry button: toggle telemetry field
    - next page button: toggle user interface

    ![screenshot](images/step_04.png)

To exit the app, press and hold the return button.

## Satellite Image

For flights at your local airfield, you can either use the included blank map (shown below) or add a 480x272 satellite image of your airfield to the `SCRIPTS/TOOLS/gpsViewer` directory and update [lib_config.lua](SCRIPTS/TOOLS/gpsViewer/lib_config.lua) with the minimum and maximum longitude and latitude coordinates of your image.

![screenshot](images/blank_map.png)

To generate a 480x272 satellite image, you can use [this map generator](https://ethosmap.hobby4life.nl/).  Alternatively, you can use [Google Maps](https://www.google.com/maps), take a screenshot, and manually crop and resize it using a free image editing program like [Gimp](https://www.gimp.org/).

## Log File Requirements

Log files are ignored if they don't have a GPS field or are over 2 MB in size.  The size limit can be increased by editing [lib_config.lua](SCRIPTS/TOOLS/gpsViewer/lib_config.lua), but this will result in long load times for large log files.  Instead, it is recommended to keep log files small by using a logging frequency of 1 Hz or less in EdgeTX.
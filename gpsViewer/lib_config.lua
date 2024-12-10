local M = {}

-- ignore large log files to keep load times reasonable
M.max_log_size_mb = 2

-- ignore short log files to exclude ground tests
M.min_log_length_sec = 60

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
      long_min = -97.61791942201334,
      long_max = -97.5870073139149,
      lat_min = 30.315438505562526,
      lat_max = 30.330617687727617
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

return M
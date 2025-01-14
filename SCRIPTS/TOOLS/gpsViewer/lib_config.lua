local M = {}

-- ignore large log files to keep load times reasonable
M.max_log_size_mb = 2

-- ignore short log files to exclude test flights
M.min_log_length_sec = 60

M.maps = {
    {
      name = "ARCA small",
      path = "/SCRIPTS/TOOLS/gpsViewer/arca_small.png",
      long_min = -97.6074,
      long_max = -97.5984,
      lat_min = 30.3223,
      lat_max = 30.3267
    },
    {
      name = "ARCA large",
      path = "/SCRIPTS/TOOLS/gpsViewer/arca_large.png",
      long_min = -97.6179,
      long_max = -97.5870,
      lat_min = 30.3154,
      lat_max = 30.3306
    },
    {
      -- plot flights at any location on a dark green background
      name = "Blank",
      path = nil,
      long_min = nil,
      long_max = nil,
      lat_min = nil,
      lat_max = nil
    },
}

return M
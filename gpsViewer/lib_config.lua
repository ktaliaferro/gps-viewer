local M = {}

M.max_log_size_mb = 2
M.min_log_length_sec = 60

M.maps = {
    {
      name = "ARCA small",
      image = Bitmap.open("/SCRIPTS/TOOLS/gpsViewer/arca_small.png"),
      long_min = -97.6074597097314,
      long_max = -97.59857623367657,
      lat_min = 30.322538058896907,
      lat_max = 30.326649900592205
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
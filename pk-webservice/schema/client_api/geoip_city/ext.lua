-- TODO: generalize
api:extend_context "pk-webservice.geoip.city" (function()

require 'geoip.city' -- TODO: Hack. This should be handled by apigen.

--------------------------------------------------------------------------------

local geodb = assert(
    geoip.city.open(
        -- TODO: Do not hardcode paths!
        luarocks_show_rock_dir('pk-webservice.geoip.city.data')
     .. "/data/geoip/GeoLiteCity.dat"
      )
  )

return
{
  factory = invariant(geodb); -- a singleton
}

--------------------------------------------------------------------------------

end);

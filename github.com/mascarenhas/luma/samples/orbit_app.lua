require_for_syntax[[orbit_dsl]]

require"orbit"

module("hello", package.seeall, orbit.app)

orbit_application [[

  -- Methods for application object

  method foo(x)
  end

  -- Models

  model post
    method find_comments()
    end
    method find_months(section_id)
    end
  end

  -- Controllers

  action section <- "/section/(%d+)"
    method get(section_id)
    end
  end

  -- Views

  view layout()
  end

  view index(params)
  end

]]

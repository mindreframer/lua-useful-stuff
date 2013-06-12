//------------------------------------------------------------------------------
// board.js: Generalized board for turn-based board game with chips, match-3 like
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GameEngine')

PKEngine.GameEngine.Board = new function()
{

//----------------------------------------------------------------------------
// Constants
//----------------------------------------------------------------------------

this.EMPTY_CHIP = 0

/*
  Creates a new board

  @param {object} chips : 2D array of chips

  @return {object} New new match-3 game controller
*/
this.make = function(chips)
{
return new function()
{

var chips_

var width_
var height_

var topology_

var event_listeners_ = { change: [] }

var on_change_ // callback on any board change


//------------------------------------------------------------------------------
// Init
//------------------------------------------------------------------------------

this.init = function(chips)
{
  assert(chips)

  chips_ = PK.clone(chips)

  width_ = assert(chips[1]).length
  height_ = chips.length

  // TODO: Must have such parameters?  Seems we don't need them here
  var CELL_W = 16, CELL_H = 16, POS_X = 0, POS_Y = 0

  topology_ = PKEngine.GameEngine.Topology.make_topology(
    PKEngine.GameEngine.Topology.TOPOLOGY_TYPE.SQUARE,
    width_, height_,
    CELL_W, CELL_H, POS_X, POS_Y
  )

  on_change_(true)
}


//------------------------------------------------------------------------------
// Listeners
//------------------------------------------------------------------------------

on_change_ = function(full_board, cells)
{
  //console.log("[Board.on_change_]:", full_board, cells, event_listeners_.change)

  if(!event_listeners_.change || event_listeners_.change.length == 0)
    return

  for( var i = 0; i < event_listeners_.change.length; i++ )
    event_listeners_.change[i](full_board, cells)
}

this.add_change_listener = function(listener)
{
  event_listeners_.change.push(listener)
}


//------------------------------------------------------------------------------
// Indicators
//------------------------------------------------------------------------------

this.make_same_cell_type_indicator = function(chip)
{
  var board = this
  return function(cell)
  {
    return board.get_chip(cell) == chip
  }
}


//------------------------------------------------------------------------------
// Getters
//------------------------------------------------------------------------------

this.get_width = function() { return width_ }
this.get_height = function() { return height_ }

this.get_topology = function() { return topology_ }


//------------------------------------------------------------------------------
// Get chips
//------------------------------------------------------------------------------

this.get_chips = function()
{
  return chips_
}


//------------------------------------------------------------------------------
// Has same chips
//------------------------------------------------------------------------------

this.has_same_chips = function(chips)
{
  for(var x = 0; x < width_; x++)
    for(var y = 0; y < height_; y++)
      if(this.get_chip({ x:x, y:y }) != chips[x][y])
      {
        //console.log("Point of difference:", x, y)
        return false
      }
  return true
}


//------------------------------------------------------------------------------
// Get chip
//------------------------------------------------------------------------------

this.get_chip = function(cell)
{
  assert(cell.x >= 0 && cell.x < width_, I18N('[get_chip] Invalid x: ${1}', cell.x))
  assert(cell.y >= 0 && cell.y < height_, I18N('[get_chip] Invalid y: ${1}', cell.y))
  return chips_[cell.x][cell.y]
}


//------------------------------------------------------------------------------
// Get chip
//------------------------------------------------------------------------------

this.cell_is_empty = function(cell)
{
  return chips_[cell.x][cell.y] == PKEngine.GameEngine.Board.EMPTY_CHIP
}


//------------------------------------------------------------------------------
// Remove chip
//------------------------------------------------------------------------------

this.remove_chip = function(cell)
{
  chips_[cell.x][cell.y] = PKEngine.GameEngine.Board.EMPTY_CHIP

  on_change_(false, [cell])
}


//------------------------------------------------------------------------------
// Place chip
//------------------------------------------------------------------------------

this.place_chip = function(cell, chip)
{
  chips_[cell.x][cell.y] = chip

  on_change_(false, [cell])
}


//------------------------------------------------------------------------------
// Swap chips
//------------------------------------------------------------------------------

this.swap_chips = function(from, to)
{
  assert(from)
  assert(to)
  assert(from.x >= 0 && from.x < width_, I18N('[get_chip] Invalid from.x: ${1}', from.x))
  assert(from.y >= 0 && from.y < height_, I18N('[get_chip] Invalid from.y: ${1}', from.y))
  assert(to.x >= 0 && to.x < width_, I18N('[get_chip] Invalid to.x: ${1}', to.x))
  assert(to.y >= 0 && to.y < height_, I18N('[get_chip] Invalid to.y: ${1}', to.y))

  var chip = chips_[from.x][from.y]

  chips_[from.x][from.y] = chips_[to.x][to.y]
  chips_[to.x][to.y] = chip

  on_change_(false, [from, to])
}


//------------------------------------------------------------------------------
// Run ray
//------------------------------------------------------------------------------

this.run_ray = function(cell, dir, indicator, check_start_cell, stop_at_first_unsatisfying)
{
  var ray

  if (check_start_cell)
  {
    if(!indicator(cell))
      return []
    ray = [ cell ]
  }
  else
  {
    ray = []
  }

  cell = topology_.get_adjacent_cell(cell, dir)
  while (cell)
  {
    if (indicator(cell))
      ray.push(cell)
    else if (stop_at_first_unsatisfying)
      return ray

    cell = topology_.get_adjacent_cell(cell, dir)
  }

  return ray
}


//------------------------------------------------------------------------------
// Fill chips
//------------------------------------------------------------------------------

this.fill_chips = function(chips, fail_on_difference)
{
  assert(chips && chips.length > 0)
  if (fail_on_difference === undefined) fail_on_difference = false

  var filled_chips = PKEngine.GameEngine.Board.make_chips(assert(width_), assert(height_))

  for(var x = 0; x < width_; x++)
    for(var y = 0; y < height_; y++)
    {
      if (this.cell_is_empty({x:x,y:y}))
      {
        var chip = chips[x][y]
        chips_[x][y] = chip
        filled_chips[x][y] = chip
      }
      else
      {
        if (fail_on_difference && chips_[x][y] != chips[x][y])
        {
//           console.log("[OWN CHIPS]")
//           console.log(PKEngine.GameEngine.Board.chips2string(chips_))
//           console.log("[RECEIVED CHIPS]")
//           console.log(PKEngine.GameEngine.Board.chips2string(chips))
//           console.log("Difference in coords:", x, y)
          CRITICAL_ERROR(I18N('Attempted to change non-empty chips!'))
        }
      }
    }

  on_change_(true)

  return filled_chips
}


//------------------------------------------------------------------------------
// Burn chips
//------------------------------------------------------------------------------

this.burn_chips = function(min_length_to_burn)
{
  //console.log("[Board.burn_chips]:", PK.clone(this.get_chips()))

  var burned_chips = PKEngine.GameEngine.Board.make_cell_list()

  // Determine burned

  for(var x = 0; x < width_; x++)
    for(var y = 0; y < height_; y++)
    {
      var cell = { x: x, y: y }
      if (!this.cell_is_empty(cell))
      {
        var chip = this.get_chip(cell)

        var left = topology_.get_adjacent_cell(cell, PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.LEFT)
        if(!left || this.get_chip(left) != chip)
        {
          var ray = this.run_ray(
              cell,
              PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.RIGHT,
              this.make_same_cell_type_indicator(chip),
              true, // check start cell
              true  // stop at first unsatisfying cell
            )

          if(ray && ray.length >= min_length_to_burn)
            burned_chips = burned_chips.concat(ray)
        }

        var up = topology_.get_adjacent_cell(cell, PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.UP)
        if(!up || this.get_chip(up) != chip)
        {
          var ray = this.run_ray(
              cell,
              PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.DOWN,
              this.make_same_cell_type_indicator(chip),
              true, // check start cell
              true  // stop at first unsatisfying cell
            )

          if(ray && ray.length >= min_length_to_burn)
            burned_chips = burned_chips.concat(ray)
        }
      }
    }

  // Burn

  for (var i = 0; i < burned_chips.length; i++)
    this.remove_chip({ x: burned_chips[i].x, y: burned_chips[i].y })

  on_change_(true)

  //console.log("[Board.burn_chips] result :", PK.clone(burned_chips), PK.clone(this.get_chips()))
  return burned_chips
}



//------------------------------------------------------------------------------
// Shift chips down
//------------------------------------------------------------------------------

this.shift_chips_down = function()
{
  //console.log("[Board.shift_chips_down]:", PK.clone(this.get_chips()))

  var shift_chips = PKEngine.GameEngine.Board.make_chip_move_list()

  for(var x = 0; x < width_; x++)
  {
    var dy = 0
    for(var y = height_-1; y >=0; y--)
    {
      var cell = { x: x, y: y }
      if (this.cell_is_empty(cell))
        dy++
      else if (dy != 0)
      {
        var type = this.get_chip(cell)

        shift_chips.push({ x: x, y: y, type: type, dx: 0, dy: dy })

        this.remove_chip(cell)
        this.place_chip( { x: cell.x, y: cell.y + dy }, type)
      }
    }
  }

  on_change_(true)

  //console.log("[Board.shift_chips_down] result :", PK.clone(shift_chips), PK.clone(this.get_chips()))
  return shift_chips
}


//------------------------------------------------------------------------------
// End of constructor
//------------------------------------------------------------------------------

  this.init(chips)

}}

/*
  Creates a new 2D array of chips

  @param {natural} width : Width
  @param {natural} height : Height

  @return {object} New chips array
*/
this.make_chips = function(width, height)
{
  var chips = []

  for(var x = 0; x < width; x++)
  {
    var column = []
    for(var y = 0; y < height; y++) column.push(PKEngine.GameEngine.Board.EMPTY_CHIP)
    chips.push(column)
  }

  return chips
}


/*
  Converts chips into string

  @param {object} chips : chips

  @return {string} Resulting multiline string
*/
this.chips2string = function(chips)
{
  var result = ""

  var width = chips.length
  var height = chips[0].length

  for(var y = 0; y < height; y++)
  {
    for(var x = 0; x < width; x++)
    {
      result += chips[x][y] + " "
    }
    result += "\n"
  }

  return result
}

/*
  Creates a new list of chips

  @return {object} New list of chips
*/
this.make_cell_list = function()
{
  // Note: This array will contain triplets { x: X, y: Y }
  return []
}

/*
  Creates a new list of moved chips

  @return {object} New list of moved chips
*/
this.make_chip_move_list = function()
{
  // Note: This array will contain { x: OLD_X, y: OLD_Y, type: TYPE, dx: DX, dy: DY }
  return []
}

}

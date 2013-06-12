//------------------------------------------------------------------------------
// topology.js: Work with topology nets
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PKEngine.check_namespace('GameEngine')

PKEngine.GameEngine.Topology = new function()
{

//------------------------------------------------------------------------------
// Constants
//------------------------------------------------------------------------------

this.TOPOLOGY_TYPE =
{
  INVALID:    0,
  SQUARE:     1,
  HEXAGONAL:  2
}

this.ADJACENCY_DIRECTION = {
  NONE  : 0,
  UP    : 1,
  LEFT  : 2,
  DOWN  : 3,
  RIGHT : 4
}

this.VALID_ADJACENCY_DIRECTIONS = [
  this.ADJACENCY_DIRECTION.UP,
  this.ADJACENCY_DIRECTION.LEFT,
  this.ADJACENCY_DIRECTION.DOWN,
  this.ADJACENCY_DIRECTION.RIGHT
]

this.NUMOF_ADJACENCY_DIRECTIONS = 5


//------------------------------------------------------------------------------
// Square topology
//------------------------------------------------------------------------------

var make_square_topology_ = function(w, h, cell_w, cell_h, pos_x, pos_y) { return new function()
{

var DELTAS_ =
[
  { x:  0, y:  0 }, // none
  { x:  0, y: -1 }, // up
  { x: -1, y:  0 }, // left
  { x:  0, y: +1 }, // down
  { x: +1, y:  0 }  // right
]

//------------------------------------------------------------------------
// Public properties
//------------------------------------------------------------------------

this.pos_x = pos_x
this.pos_y = pos_y
this.w = w
this.h = h
this.cell_w = cell_w
this.cell_h = cell_h


//------------------------------------------------------------------------
// get_closest_direction
//------------------------------------------------------------------------

// Note: 'static' method
this.get_closest_direction = function(int_start, int_end)
{
  if (!int_start || !int_end)
    return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.NONE

  var x = int_end.x - int_start.x
  var y = int_end.y - int_start.y

  if ( x > 0 && x > Math.abs(y) )
    return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.RIGHT

  if ( x < 0 && -x > Math.abs(y) )
    return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.LEFT

  if ( y > 0 )
    return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.DOWN

  return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.UP
}


//------------------------------------------------------------------------
// cell_is_valid
//------------------------------------------------------------------------

this.cell_is_valid = function(cell)
{
  return typeof(cell.x) == "number" && typeof(cell.y) == "number"  &&
    cell.x >= 0 && cell.y >= 0 && cell.x < this.w && cell.y < this.h
}


//------------------------------------------------------------------------
// get_adjacency_direction_to
//------------------------------------------------------------------------

this.get_adjacency_direction_to = function(cell, other_cell)
{
  if (!this.cell_is_valid(cell) || !this.cell_is_valid(other_cell) )
    return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.NONE

  for (var i = 0; i < PKEngine.GameEngine.Topology.VALID_ADJACENCY_DIRECTIONS.length; i++)
  {
    var neighbour_in_dir = this.get_adjacent_cell(
        cell,
        PKEngine.GameEngine.Topology.VALID_ADJACENCY_DIRECTIONS[i]
      )

    if (
        neighbour_in_dir &&
        neighbour_in_dir.x == other_cell.x &&
        neighbour_in_dir.y == other_cell.y
      )
      return PKEngine.GameEngine.Topology.VALID_ADJACENCY_DIRECTIONS[i]
  }

  return PKEngine.GameEngine.Topology.ADJACENCY_DIRECTION.NONE
}


//------------------------------------------------------------------------
// cells_are_adjacent
//------------------------------------------------------------------------

this.cells_are_adjacent = function(cell1, cell2)
{
  if (!this.cell_is_valid(cell2))
    return undefined

  var neighbours = this.get_adjacent_cells(cell1)
  if (!neighbours)
    return undefined

  for(var i = 0; i < neighbours.length; i++)
    if (neighbours[i].x == cell2.x && neighbours[i].y == cell2.y)
      return true

  return false
}


//------------------------------------------------------------------------
// get_adjacent_cell
//------------------------------------------------------------------------

this.get_adjacent_cell = function(cell, dir)
{
  var cell = { x: cell.x + DELTAS_[dir].x, y: cell.y + DELTAS_[dir].y }
  if (!this.cell_is_valid(cell))
    return undefined
  return cell
}


//------------------------------------------------------------------------
// get_adjacent_cells
//------------------------------------------------------------------------

this.get_adjacent_cells = function(cell)
{
  if (!this.cell_is_valid(cell))
    return undefined

  var neighbours = []

  for (var i = 0; i < PKEngine.GameEngine.Topology.VALID_ADJACENCY_DIRECTIONS.length; i++)
  {
    var neighbour_in_dir = this.get_adjacent_cell(
        cell,
        PKEngine.GameEngine.Topology.VALID_ADJACENCY_DIRECTIONS[i]
      )

    if (neighbour_in_dir)
      neighbours.push(neighbour_in_dir)
  }

  return neighbours
}


//------------------------------------------------------------------------
// Things related to client X,Y conversion into logical X,Y
//------------------------------------------------------------------------

this.get_cell_center = function(cell)
{
  if (!this.cell_is_valid(cell))
  {
    //system.console.log("Invalid x,y:", cell.x, cell.y, this.w, this.h)
    return undefined
  }

  return {
    x: cell.x * this.cell_w + Math.floor(this.cell_w/2 + this.pos_x),
    y: cell.y * this.cell_h + Math.floor(this.cell_h/2 + this.pos_y)
  }
}

this.get_cell_from_point = function(px, py)
{
  var cell = {
    x : Math.floor( (px - this.pos_x) / this.cell_w),
    y : Math.floor( (py - this.pos_y) / this.cell_h)
  }

  if (!this.cell_is_valid(cell))
  {
    //system.console.log("Invalid px,py:", px, py, cell.x, cell.y, this.w, this.h)
    return undefined
  }

  return cell
}


} }


//------------------------------------------------------------------------------
// Topology factory
//------------------------------------------------------------------------------

/*
  Creates a topology new object, having next interface:
  {
    Properties:

      integer w         : Width of field view (in cells)
      integer h         : Height of field view (in cells)
      integer pos_x     : X position (offset in canvas) of field view (in px)
      integer pos_y     : Y position (offset in canvas) of field view (in px)
      integer cell_w    : Width of field cell (in px)
      integer cell_h    : Height of field cell (in px)

    Methods:

      function cell_is_valid (cell)
        returns true if cell has valid coordinates

      function cells_are_adjacent (cell1, cell2)
        returns true if cells are adjacent

      function get_adjacent_cell (cell, dir)
        returns adjacent cell in direction 'dir' or undefined

      function get_adjacent_cells (cell) :
        returns list of { x: x_coord_in_cells, y: y_coord_in_cells }

      function get_cell_center cell) :
        returns { x: x_coord_in_px, y: y_coord_in_px }

      function get_cell_from_point (integer x_coord_in_px, integer y_coord_in_px)
        returns { x: x_coord_in_cells, y: y_coord_in_cells }
  }

  @param {integer}   type : Type of topology, Only PKEngine.Topology.SQUARE is supported now
  @param {integer}      w : Width of field view (in cells)
  @param {integer}      h : Height of field view  (in cells)
  @param {integer} cell_w : Width of field cell (in px)
  @param {integer} cell_h : Height of field cell (in px)
  @param {integer}  pos_x : X position (offset in canvas) of field view (in px)
  @param {integer}  pos_y : Y position (offset in canvas) of field view (in px)

  @return {object} A new topology net object
*/
this.make_topology = function(type, w, h, cell_w, cell_h, pos_x, pos_y)
{
  if (type !== this.TOPOLOGY_TYPE.SQUARE)
  {
    //system.console.log("Invalid topology type:", type)
    return undefined
  }

  return make_square_topology_(w, h, cell_w, cell_h, pos_x, pos_y)
}

}

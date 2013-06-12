//------------------------------------------------------------------------------
// undo_redo.js: Undo/redo functionality
// This file is a part of pk-core-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------

PK.make_undo_redo = function(max_depth)
{
  assert(max_depth > 0, "Max depth for undo/redo must be a positive value")

  return new function()
  {
    var max_depth_ = max_depth
    var read_only_ = false

    // undo: state 1 .. state N
    // redo: state N+M .. state N+1
    var undo_stack_ = [], redo_stack_ = [], current_memento_ = undefined

    var Copy_memento_ = function(memento)
    {
      return PK.clone(memento)
    }

    this.Is_read_only = function() { return read_only_ }
    this.Make_read_only = function(f) { read_only_ = f }

    this.Clear = function()
    {
      if (this.Is_read_only()) return
      undo_stack_ = []
      redo_stack_ = []
      current_memento_ = undefined
    }

    this.Can_undo = function() { return undo_stack_.length > 0 }
    this.Can_redo = function() { return redo_stack_.length > 0 }

    this.Before_do = function(memento)
    {
      if (this.Is_read_only()) return

      if (undo_stack_.length + 1 > max_depth_)
      {
        undo_stack_.shift()
      }

      undo_stack_.push(Copy_memento_(memento))
      redo_stack_ = []
      current_memento_ = undefined
    }

    this.Undo = function(current_memento)
    {
      if (this.Is_read_only()) return
      if (!this.Can_undo()) return
      redo_stack_.push(Copy_memento_(current_memento))
      current_memento_ = undo_stack_.pop()
      return Copy_memento_(current_memento_)
    }

    this.Redo = function()
    {
      if (this.Is_read_only()) return
      if (!this.Can_redo()) return
      assert(current_memento_ !== undefined, "Undefined current memento")
      undo_stack_.push(current_memento_)
      current_memento_ = redo_stack_.pop()
      return Copy_memento_(current_memento_)
    }
  }
}

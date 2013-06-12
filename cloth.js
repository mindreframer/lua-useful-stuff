/*
Copyright (c) 2013 Stuffit at codepen.io (http://codepen.io/stuffit)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*/

// settings

var physics_accuracy = 30,
   mouse_influence   = 20,
   mouse_cut         = 6,
   gravity           = 900,
   cloth_height      = 30,
   cloth_width       = 50,
   start_y           = 20,
   spacing           = 7,
   tear_distance     = 15;


window.requestAnimFrame =
window.requestAnimationFrame       ||
window.webkitRequestAnimationFrame ||
window.mozRequestAnimationFrame    ||
window.oRequestAnimationFrame      ||
window.msRequestAnimationFrame     ||
function(callback) {
    window.setTimeout(callback, 1000 / 60);
};

var canvas,
  ctx,
  points,
  physics,
  mouse = {
    down: false,
    button: 1,
    x: 0,
    y: 0,
    px: 0,
    py: 0
  };

window.onload = function() {

  canvas = document.getElementById('c');
  ctx    = canvas.getContext('2d');

  canvas.width  = 600;//window.innerWidth;
  canvas.height = 320;//window.innerHeight;

  canvas.onmousedown = function(e) {
    mouse.button = e.which;
    mouse.px = mouse.x;
    mouse.py = mouse.y;
    mouse.x = e.clientX || e.layerX;
    mouse.y = e.clientY || e.layerY;
    mouse.down = true;
    e.preventDefault();
  };

  canvas.onmouseup = function(e) {
    mouse.down = false;
    e.preventDefault();
  };

  canvas.onmousemove = function(e) {
    mouse.px = mouse.x;
    mouse.py = mouse.y;
    mouse.x = e.clientX || e.layerX;
    mouse.y = e.clientY || e.layerY;
    e.preventDefault();
  };

  canvas.oncontextmenu = function(e) {
    e.preventDefault();
  };

  init();
};

var Constraint = function(p1, p2, spacing, tear_distance) {

  this.p1 = p1;
  this.p2 = p2;
  this.length = spacing;
  this.tear_distance = tear_distance;
};

Constraint.prototype.solve = function() {

  var diff_x = this.p1.x - this.p2.x,
    diff_y = this.p1.y - this.p2.y,
    dist = Math.sqrt(diff_x * diff_x + diff_y * diff_y),
    diff = (this.length - dist) / dist;

  if (dist > this.tear_distance) this.p1.remove_constraint(this);

  var scalar_1 = ((1 / this.p1.mass) / ((1 / this.p1.mass) + (1 / this.p2.mass))),
    scalar_2 = 1 - scalar_1;

  this.p1.x += diff_x * scalar_1 * diff;
  this.p1.y += diff_y * scalar_1 * diff;

  this.p2.x -= diff_x * scalar_2 * diff;
  this.p2.y -= diff_y * scalar_2 * diff;
};

Constraint.prototype.draw = function() {
  ctx.moveTo(this.p1.x, this.p1.y);
  ctx.lineTo(this.p2.x, this.p2.y);
};

var Point = function(x, y) {

  this.x = x;
  this.y = y;
  this.px = x;
  this.py = y;
  this.ax = 0;
  this.ay = 0;
  this.mass = 1;
  this.constraints = [];
  this.pinned = false;
  this.pin_x;
  this.pin_y;
};

Point.prototype.update = function(delta) {

  this.add_force(0, this.mass * gravity);

  var vx = this.x - this.px,
      vy = this.y - this.py;

  delta *= delta;
  nx = this.x + 0.99 * vx + 0.5 * this.ax * delta;
  ny = this.y + 0.99 * vy + 0.5 * this.ay * delta;

  this.px = this.x;
  this.py = this.y;

  this.x = nx;
  this.y = ny;

  this.ay = this.ax = 0
};

Point.prototype.update_mouse = function() {

  if (!mouse.down) return;

  var diff_x = this.x - mouse.x,
    diff_y = this.y - mouse.y,
    dist   = Math.sqrt(diff_x * diff_x + diff_y * diff_y);

  if (mouse.button == 1) {

    if(dist < mouse_influence) {
      this.px = this.x - (mouse.x - mouse.px) * 1.8;
      this.py = this.y - (mouse.y - mouse.py) * 1.8;
    }

  } else if (dist < mouse_cut) this.constraints = [];
};

Point.prototype.draw = function() {

  if (this.constraints.length <= 0) return;
  var i = this.constraints.length;
  while(i--) this.constraints[i].draw();
};

Point.prototype.solve_constraints = function() {

  var i = this.constraints.length;
  while(i--) this.constraints[i].solve();

  if (this.y < 1) this.y = 2 * (1) - this.y;
  else if (this.y > canvas.height-1) this.y = 2 * (canvas.height - 1) - this.y;

  if (this.x > canvas.width-1) this.x = 2 * (canvas.width - 1) - this.x;
  else if (this.x < 1) this.x = 2 * (1) - this.x;

  if (this.pinned) {
    this.x = this.pin_x;
    this.y = this.pin_y;
  }
};

Point.prototype.attach = function(P, spacing, tear_distance) {

  this.constraints.push(
    new Constraint(this, P, spacing, tear_distance)
    );
};

Point.prototype.remove_constraint = function(lnk) {

  var i = this.constraints.length;
  while(i--) if(this.constraints[i] == lnk) this.constraints.splice(i, 1);
};

Point.prototype.add_force = function(fX, fY) {

  this.ax += fX/this.mass;
  this.ay += fY/this.mass;
};

Point.prototype.pin = function(pX, pY) {

  this.pinned = true;
  this.pin_x = pX;
  this.pin_y = pY;
};

var Physics = function() {

  this.delta_sec = 16 / 1000;
  this.accuracy = physics_accuracy;
};

Physics.prototype.update = function() {

  var i = this.accuracy;

  while(i--) {
    var p = points.length;
    while(p--) points[p].solve_constraints();
  }

  i = points.length;
  while(i--) {
    points[i].update_mouse();
    points[i].update(this.delta_sec);
  }
};

function init() {

  physics = new Physics();
  points = [];
  build_cloth();
  update();
}

function update() {

  ctx.clearRect(0, 0, canvas.width, canvas.height);

  physics.update();

  ctx.strokeStyle = 'rgba(222,222,222,0.6)';
  ctx.beginPath();
  var i = points.length;
  while(i--) points[i].draw();
  ctx.stroke();

  requestAnimFrame(update);
}

function build_cloth() {

  var start_x = canvas.width / 2 - cloth_width * spacing / 2;

  for(var y = 0; y <= cloth_height; y++) {

    for(var x = 0; x <= cloth_width; x++) {

      var p = new Point(start_x + x * spacing, y * spacing + start_y);

      0 !== x &&
      p.attach(points[points.length - 1], spacing, tear_distance);

      0 !== y &&
      p.attach(points[(y - 1) * (cloth_width + 1) + x], spacing, tear_distance);

      0 === y &&
      p.pin(p.x, p.y);

      points.push(p)
    }
  }
}
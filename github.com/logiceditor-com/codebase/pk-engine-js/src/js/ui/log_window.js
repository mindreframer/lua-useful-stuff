PKEngine.Log_window = new function ()
{
  var br_ = '<br>'

  var header_ = ['--------- SYSTEM LOG ---------------------', br_]
  var footer_ = ['--------- END OF LOG ---------------------', br_]

  this.show = function()
  {
    var log_window = document.getElementById("log_window");
    if(!log_window)
      return

    var text = header_.join('') + br_ + PK.log_system.list().join(br_) + br_ + footer_.join('')

    log_window.innerHTML = text

    PKEngine.GUI.Viewport.hide_game_field()
    log_window.style.display = 'block'
  }

  this.hide = function()
  {
    var log_window = document.getElementById("log_window");
    if(!log_window)
      return

    log_window.style.display = 'none'
    PKEngine.GUI.Viewport.show_game_field()
  }

  this.toggle = function()
  {
    var log_window = document.getElementById("log_window");
    if(!log_window)
      return

    if (log_window.style.display == 'block')
      PKEngine.Log_window.hide()
    else
      PKEngine.Log_window.show()
  }
}

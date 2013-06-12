//------------------------------------------------------------------------------
// ipad_add2home.js: Tip screen for add to Home on iPad
// This file is a part of pk-engine-js library
// Copyright (c) Alexander Gladysh <ag@logiceditor.com>
// Copyright (c) Dmitry Potapov <dp@logiceditor.com>
// See file `COPYRIGHT` for the license
//------------------------------------------------------------------------------
//
// Inspired by MIT-licensed library https://github.com/cubiq/add-to-homescreen
//
//------------------------------------------------------------------------------

PKEngine.iPadAdd2Home = new function()
{
  //NOTE: set in init() function
  var must_show_add2home_tip_screen_ = false;

  var startX;
  var nav = navigator,
    isRetina = 'devicePixelRatio' in window && window.devicePixelRatio > 1,
    iPadAdd2HomeKey = "already_launched",
    startY = startX = 0,
    Interval, closeTimeout, div_element,
    options = {
      startDelay: 2000,     // 2 seconds from page load before the balloon appears
      lifespan: 20000,      // 20 seconds before it is automatically destroyed
      bottomOffset: 14,     // Distance of the balloon from bottom
      message: '',
      arrow: true           // Display the balloon arrow
    };

  var show_add2home_tip_screen_ = function()
  {
    var div = document.createElement('div'),
      close,
      link = document.querySelectorAll('head link[rel=apple-touch-icon]'),
      sizes, touchIcon = '';

    div.id = 'iPadAdd2Home';
    div.style.cssText += 'position:absolute;-webkit-transition-property:-webkit-transform,opacity;-webkit-transition-duration:0;-webkit-transform:translate3d(0,0,0);';
    div.style.left = '-9999px';

    options.message = I18N('ipad_add2home');

    // Search for the apple-touch-icon
    if (link.length)
    {
      for (var i=0, l=link.length; i<l; i++)
      {
        sizes = link[i].getAttribute('sizes');

        if (sizes) {
          if (isRetina && sizes == '114x114')
          {
            touchIcon = link[i].href;
            break;
          }
        }
        else
        {
          touchIcon = link[i].href;
        }
      }

      touchIcon = '<span style="background-image:url(' + touchIcon + ')" class="touchIcon"></span>';
    }

    div.className = 'ipad wide';
    div.innerHTML = touchIcon + options.message.replace('%device', "iPad").replace('%icon', '<span class="share"></span>') + (options.arrow ? '<span class="arrow"></span>' : '') + '<span class="close">\u00D7</span>';

    document.body.appendChild(div);
    div_element = div;

    close = div_element.querySelector('.close');
    if (close && close.addEventListener)
      close.addEventListener('click', close_add2home_tip_screen_, false);

    PK.WebStorage.set_item(iPadAdd2HomeKey, 'true');

    setTimeout(
      function()
      {
        div_element.style.top = window.scrollY + options.bottomOffset + 'px';
        div_element.style.left =  window.scrollX + 206 - Math.round(div_element.offsetWidth/2) + 'px';

        div_element.style.webkitTransform = 'translate3d(0,' + -(window.scrollY + options.bottomOffset + div_element.offsetHeight) + 'px,0)';

        setTimeout(
          function ()
          {
            div_element.style.webkitTransitionDuration = '0.6s';
            div_element.style.opacity = '1';
            div_element.style.webkitTransform = 'translate3d(0,0,0)';
            div_element.addEventListener('webkitTransitionEnd', transition_end_, false);
          },
          0
        );

        closeTimeout = setTimeout(close_add2home_tip_screen_, options.lifespan);
      },
      options.startDelay
    );
  }

  var transition_end_ = function()
  {
    div_element.removeEventListener('webkitTransitionEnd', transition_end_, false);
    div_element.style.webkitTransitionProperty = '-webkit-transform';
    div_element.style.webkitTransitionDuration = '0.2s';

    if (closeTimeout)
    {
      clearInterval(Interval);
      Interval = setInterval(set_position_, 100);
    }
    else
    {
      div_element.parentNode.removeChild(div_element);
    }
  }

  var set_position_ = function()
  {
    var matrix = new WebKitCSSMatrix(window.getComputedStyle(div_element, null).webkitTransform),
      posY = window.scrollY - startY,
      posX = window.scrollX - startX;

    if (posY == matrix.m42 && posX == matrix.m41) return;

    clearInterval(Interval);
    div_element.removeEventListener('webkitTransitionEnd', transition_end_, false);

    setTimeout(
      function()
      {
        div_element.addEventListener('webkitTransitionEnd', transition_end_, false);
        div_element.style.webkitTransform = 'translate3d(' + posX + 'px,' + posY + 'px,0)';
      },
      0
    );
  }

  var close_add2home_tip_screen_ = function()
  {
    clearInterval(Interval);
    clearTimeout(closeTimeout);
    closeTimeout = null;
    div_element.removeEventListener('webkitTransitionEnd', transition_end_, false);

    var posY = window.scrollY - startY,
      posX = window.scrollX - startX,
      close = div_element.querySelector('.close');

    if (close)
      close.removeEventListener('click', close_add2home_tip_screen_, false);

    div_element.style.webkitTransitionProperty = '-webkit-transform,opacity';

    div_element.addEventListener('webkitTransitionEnd', transition_end_, false);
    div_element.style.opacity = '0';
    div_element.style.webkitTransitionDuration = '0.8s';
    div_element.style.webkitTransform = 'translate3d(' + posX + 'px,' + posY + 'px,0)';
  }

  this.init = function(platform_type, is_launched_in_social_net)
  {
    if (platform_type == PKEngine.Platform.TYPE.IPAD && !is_launched_in_social_net)
    {
      must_show_add2home_tip_screen_ = true;
    }
  }

  this.show = function()
  {
    if (
         must_show_add2home_tip_screen_ && PK.WebStorage.available()
         && !PK.WebStorage.read_item(iPadAdd2HomeKey)
       )
    {
      show_add2home_tip_screen_();
    }
  }
};

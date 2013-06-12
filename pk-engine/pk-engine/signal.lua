--------------------------------------------------------------------------------
-- signal.lua: signal constants
-- This file is a part of pk-engine library
-- Copyright (c) Alexander Gladysh <ag@logiceditor.com>
-- Copyright (c) Dmitry Potapov <dp@logiceditor.com>
-- See file `COPYRIGHT` for the license
--------------------------------------------------------------------------------
--
-- TODO: Move to lua-aplicado
--
--------------------------------------------------------------------------------

return
{
  SIGHUP	  = 1;
  SIGINT	  = 2;
  SIGQUIT	  = 3;
  SIGILL	  = 4;
  SIGTRAP	  = 5;
  SIGABRT	  = 6;
  SIGIOT	  = 6;
  SIGFPE	  = 8;
  SIGKILL	  = 9;
  SIGBUS	  = 10;
  SIGSEGV	  = 11;
  SIGSYS	  = 12;
  SIGPIPE	  = 13;
  SIGALRM	  = 14;
  SIGTERM	  = 15;
  SIGURG	  = 16;
  SIGSTOP	  = 17;
  SIGCONT	  = 19;
  SIGCHLD	  = 20;
  SIGTTIN	  = 21;
  SIGTTOU	  = 22;
  SIGIO	    = 23;
  SIGXCPU	  = 24;
  SIGXFSZ	  = 25;
  SIGVTALRM	= 26;
  SIGPROF	  = 27;
  SIGWINCH	= 28;
  SIGUSR1	  = 30;
  SIGUSR2	  = 31;
}

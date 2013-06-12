function SetGlobalSessionCookies()
{
  var MINUTES_TILL_EXPIRATION = 10;

  var
    server_answer_error = Get_Cookie("server_answer_error"),
    uid = Get_Cookie("uid"),
    sid = Get_Cookie("sid"),
    username = Get_Cookie("username"),
    profile = Get_Cookie("profile");

  Delete_Cookie("uid", "/session");
  Delete_Cookie("sid", "/session");
  Delete_Cookie("username","/session");
  Delete_Cookie("profile", "/session");
  Delete_Cookie("server_answer_error", "/session");

  if (server_answer_error != null)
    Set_Cookie("server_answer_error", server_answer_error, MINUTES_TILL_EXPIRATION * 60, "/");

  if (uid != null)
    Set_Cookie("uid",       uid,      MINUTES_TILL_EXPIRATION * 60, "/");

  if (sid != null)
    Set_Cookie("sid",       sid,      MINUTES_TILL_EXPIRATION * 60, "/");

  if (username != null)
    Set_Cookie("username",  username, MINUTES_TILL_EXPIRATION * 60, "/");

  if (profile != null)
    Set_Cookie("profile",   profile,  MINUTES_TILL_EXPIRATION * 60, "/");
}

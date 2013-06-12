-- Sample Nmap Scripting Engine (NSE) script
-- Finds Rails applications and prints their title element contents
--
-- USAGE: nmap -n -Pn -p 3000 --open --script rails-dev-finder.nse 10.0.1.0/24

description = [[ Find machines running Rails apps in dev mode and report on the title of their app ]]

categories = {"safe", "discovery"}

require 'stdnse'
require 'http'

--Only act on std Rails dev port
function portrule(host, port)
  return port.number == 3000
end

function action(host, port)
  local response, app_title
  response = http.get(host, port, "/")

  if response.status and response.status ~= 404 then
    app_title = title_from_body(response.body)
    return "'"..app_title.."'"
  end
end

function title_from_body(body)
  return string.match(body,"<title>(.+)</title>")
end


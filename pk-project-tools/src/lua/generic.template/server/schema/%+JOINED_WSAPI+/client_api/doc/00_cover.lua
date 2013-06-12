--[[
Available placeholders:

  -- ${version} -- API version
  -- ${generation_date} -- document generation date
  -- ${index} -- contents
  -- ${endofsection} -- page break
  -- ${h1:Title} -- level 2 title, goes in index
  -- ${h2:Title} -- level 2 title, goes in index
  -- ${h3:Title} -- level 3 title, goes in index
  -- ${h4:Title} -- level 4 title, goes in index
  -- ${h5:Title} -- level 5 title, goes in index
  -- ${/:call} -- reference to /call
  -- ${@/:call} -- embed definition of /call
  -- ${T:TYPENAME} -- reference to typename
  -- ${@T:*} -- embed data types doc
  -- ${E:EVENTNAME} -- reference to event
  -- ${@E:EVENTNAME} -- embed definition of event
  -- ${!:ERRORCODE} -- reference to error code
  -- ${VERSION:<code>} -- Version header in changelog

--]]

doc:text "00_cover"
[[
% #{PROJECT_DOMAIN}. Клиентский протокол (API)
% #{PROJECT_TEAM} <#{PROJECT_MAIL}>
\thispagestyle{empty}

\begin{flushright}
\emph{Версия:} ${version}
\end{flushright}

${endofsection}

${index}
${endofsection}
]]

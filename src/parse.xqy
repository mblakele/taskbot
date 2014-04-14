xquery version "1.0-ml";
(: Parse test.
 : This assumes libraries are xqm not xqy.
 :)

import module namespace tb="ns://blakeley.com/taskbot"
  at "taskbot.xqm" ;

current-dateTime(),
for $f as xs:string in xdmp:filesystem-directory(
  xdmp:modules-root())/dir:entry[dir:type eq 'file'][
  ends-with(dir:filename, '.xqy')]/dir:filename
where $f ne 'parse.xqy'
return xdmp:invoke(
  $f,
  (),
  <options xmlns="xdmp:eval"><static-check>true</static-check></options>)

(: parse.xqy :)
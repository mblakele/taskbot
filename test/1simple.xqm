xquery version "1.0-ml";
(:
 : 1simple.xqm
 :
 : Test suite stage 1: read-only.
 :
 :)
module namespace t="http://github.com/robwhitby/xray/test";

import module namespace at="http://github.com/robwhitby/xray/assertions"
  at "/xray/src/assertions.xqy";

import module namespace tb="ns://blakeley.com/taskbot"
  at "/src/taskbot.xqm" ;

(: NB - functions run in alphabetical order! :)

(: The first set of tests do not need updates. :)

declare %t:case function assignment()
{
  at:equal(
    tb:uri-list-by-assignment(
      (1 to 10) ! ("test/"||.),
      1 to 2,
      1),
    ('test/2',
      'test/3',
      'test/4',
      'test/7',
      'test/8'))
};

declare %t:case function fatal-is-not-set()
{
  at:empty(tb:maybe-fatal())
};

declare %t:case function tasks-do-spawn()
{
  xdmp:spawn-function(
    function() { xdmp:sleep(1000) }),
  at:true(
    tb:tasks-count() gt 0)
};

declare %t:case function queue-size()
{
  at:true(
    tb:queue-size() castable as xs:integer)
};

(: 1simple.xqm :)
xquery version "1.0-ml";
(:
 : 4results.xqm
 :
 : Test suite stage 4: tasks that return results.
 :
 :)
module namespace t="http://github.com/robwhitby/xray/test";

import module namespace at="http://github.com/robwhitby/xray/assertions"
  at "/xray/src/assertions.xqy";

import module namespace tb="ns://blakeley.com/taskbot"
  at "/src/taskbot.xqm" ;

(: NB - functions run in alphabetical order! :)

(: Now run some tests that return results. :)

declare %t:case function ref-counts()
{
  at:true(
    abs(
      4.5 - (
        let $results := tb:forests-uris-process(
          tb:database-host-forests(xdmp:database(), xdmp:host()),
          ("document"),
          cts:directory-query("test/asset/", "infinity"),
          500,
          "test/asset",
          function($list as item()+, $opts as map:map?) {
            tb:maybe-fatal(),
            json:to-array(
              (count($list),
                (: Each item is a URI. :)
                count(doc($list)/asset/asset-ref))) },
          (),
          $tb:OPTIONS-SYNC)
        let $item-count := sum($results ! json:array-values(.)[1])
        let $ref-count := sum($results ! json:array-values(.)[2])
        return ($ref-count div $item-count)))
    lt 1)
};

(: test/4results.xqm :)
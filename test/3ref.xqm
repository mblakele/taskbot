xquery version "1.0-ml";
(:
 : 3ref.xqm
 :
 : Test suite stage 3: references.
 :
 :)
module namespace t="http://github.com/robwhitby/xray/test";

import module namespace at="http://github.com/robwhitby/xray/assertions"
  at "/xray/src/assertions.xqy";

import module namespace tb="ns://blakeley.com/taskbot"
  at "/src/taskbot.xqm" ;

(: NB - functions run in alphabetical order! :)

(: Now run some tests that require updates. :)

declare %t:setup function ref-enrich-assets()
{
  (: In a real application this should run on multiple hosts,
   : starting tasks for the local forests only.
   : Usually we would start one task per forest,
   : in parallel.
   :)
  tb:forests-uris-process(
    tb:database-host-forests(xdmp:database(), xdmp:host()),
    ('document'),
    cts:directory-query('test/asset/', 'infinity'),
    500,
    'test/asset',
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $uri in $list
      let $id := substring-after($uri, 'test/asset/')
      let $root := doc($uri)/asset
      let $old := $root/asset-ref-count
      (: This could also use cts:values and cts:frequency,
       : with appropriate range indexes.
       : Or consider a co-occurence map over the whole input list.
       :)
      let $new := element asset-ref-count {
        xdmp:estimate(
          cts:search(
            doc(),
            cts:and-query(
              (cts:directory-query('test/asset/', 'infinity'),
                cts:element-value-query(xs:QName('asset-ref'), $id))))) }
      where empty($old) or $new ne $old
      return (
        if ($old) then xdmp:node-replace($old, $new)
        else xdmp:node-insert-child($root, $new)),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

declare %t:setup function ref-enrich-orgs()
{
  (: In a real application this should run on multiple hosts,
   : starting tasks for the local forests only.
   : Usually we would start one task per forest,
   : in parallel.
   :)
  tb:forests-uris-process(
    tb:database-host-forests(xdmp:database(), xdmp:host()),
    ('document'),
    cts:directory-query('test/org/', 'infinity'),
    500,
    'test/org',
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $uri in $list
      let $id := substring-after($uri, 'test/org/')
      let $root := doc($uri)/org
      let $old := $root/org-asset-count
      (: This could also use cts:values and cts:frequency,
       : with appropriate range indexes.
       : Or consider a co-occurence map over the whole input list.
       :)
      let $new := element org-asset-count {
        xdmp:estimate(
          cts:search(
            doc(),
            cts:and-query(
              (cts:directory-query('test/asset/', 'infinity'),
                cts:element-value-query(xs:QName('asset-org'), $id))))) }
      where empty($old) or $new ne $old
      return (
        if ($old) then xdmp:node-replace($old, $new)
        else xdmp:node-insert-child($root, $new)),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

declare %t:setup function ref-enrich-persons()
{
  (: In a real application this should run on multiple hosts,
   : starting tasks for the local forests only.
   : Usually we would start one task per forest,
   : in parallel.
   :)
  tb:forests-uris-process(
    tb:database-host-forests(xdmp:database(), xdmp:host()),
    ('document'),
    cts:directory-query('test/person/', 'infinity'),
    500,
    'test/person',
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $uri in $list
      let $id := substring-after($uri, 'test/person/')
      let $root := doc($uri)/person
      let $old := $root/person-asset-count
      (: This could also use cts:values and cts:frequency,
       : with appropriate range indexes.
       : Or consider a co-occurence map over the whole input list.
       :)
      let $new := element person-asset-count {
        xdmp:estimate(
          cts:search(
            doc(),
            cts:and-query(
              (cts:directory-query('test/asset/', 'infinity'),
                cts:element-value-query(xs:QName('asset-person'), $id))))) }
      where empty($old) or $new ne $old
      return (
        if ($old) then xdmp:node-replace($old, $new)
        else xdmp:node-insert-child($root, $new)),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

declare %t:setup function ref-wait()
{
  tb:tasks-wait()
};

(: look for refs :)
declare %t:case function ref-Z-count-asset-refs()
{
  at:equal(
    xdmp:estimate(
      xdmp:directory('test/asset/', 'infinity')
      /asset/asset-ref-count),
    1000)
};

declare %t:case function ref-Z-count-org-assets()
{
  at:equal(
    xdmp:estimate(
      xdmp:directory('test/org/', 'infinity')
      /org/org-asset-count),
    100)
};

declare %t:case function ref-Z-count-person-assets()
{
  at:equal(
    xdmp:estimate(
      xdmp:directory('test/person/', 'infinity')
      /person/person-asset-count),
    1000)
};

(: test/3ref.xqm :)
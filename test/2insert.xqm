xquery version "1.0-ml";
(:
 : 2insert.xqm
 :
 : Test suite stage 2: raw inserts.
 :
 :)
module namespace t="http://github.com/robwhitby/xray/test";

import module namespace at="http://github.com/robwhitby/xray/assertions"
  at "/xray/src/assertions.xqy";

import module namespace tb="ns://blakeley.com/taskbot"
  at "/src/taskbot.xqm" ;

(: NB - functions run in alphabetical order! :)

(: Now run some tests that require updates. :)

declare %t:setup function insert-A-setup()
{
  xdmp:directory-delete('test/')
};

declare %t:setup function insert-assets()
{
  tb:list-segment-process(
    1 to 1000,
    500,
    "test/asset",
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $i in $list
      return xdmp:document-insert(
        "test/asset/"||$i,
        element asset {
          attribute id { 'asset'||$i },
          element asset-org { 1 + xdmp:random(99) },
          element asset-person { 1 + xdmp:random(999) },
          (1 to xdmp:random(9))
          ! element asset-ref { xdmp:random(1000) }[. ne $i] }),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

declare %t:setup function insert-orgs()
{
  tb:list-segment-process(
    1 to 100,
    500,
    "test/org",
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $i in $list
      return xdmp:document-insert(
        "test/org/"||$i,
        element org { attribute id { 'org'||$i } }),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

declare %t:setup function insert-persons()
{
  tb:list-segment-process(
    1 to 1000,
    500,
    "test/person",
    function($list as item()+, $opts as map:map?) {
      tb:maybe-fatal(),
      for $i in $list
      return xdmp:document-insert(
        "test/person/"||$i,
        element person {
          attribute id { 'person'||$i },
          element person-org { 1 + xdmp:random(99) } }),
      xdmp:commit() },
    (),
    $tb:OPTIONS-UPDATE)
};

(: Hack - and kind of fragile too. :)
declare %t:setup function insert-wait()
{
  xdmp:sleep(1500),
  tb:tasks-wait()
};

(: Check counts. :)

declare %t:case function insert-Z-count-assets()
{
  tb:info('insert-Z-count-assets', ()),
  at:equal(
    xdmp:estimate(xdmp:directory('test/asset/', 'infinity')),
    1000)
};

declare %t:case function insert-Z-count-persons()
{
  at:equal(
    xdmp:estimate(xdmp:directory('test/person/', 'infinity')),
    1000)
};

declare %t:case function insert-Z-count-orgs()
{
  at:equal(
    xdmp:estimate(xdmp:directory('test/org/', 'infinity')),
    100)
};

(: test/2insert.xqm :)
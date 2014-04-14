# taskbot

## Introduction

Need to boil an ocean? The taskbot library can help you
put the MarkLogic Task Server to work. Simple map-reduce functions
helps you farm out as many tasks as your MarkLogic cluster
can handle, with as much concurrency as you need.

Get the job done.

## Requirements

Taskbot relies heavily on `xdmp:spawn-function`, `xdmp:invoke-function`,
and anonymous functions. These were introduced in MarkLogic 7.
In theory you could do similar things with earlier releases:
patches welcome!

## Interface

To get started with taskbot, you need a list of items to process
and the code to process each item. This might be a list of URIs
and a document enrichment module. Or a list of URLs and
some code to fetch and insert each URL into a database.
This is similar to CoRB, but without any need for Java
and less specific to updates.

### Creating 1M documents

This example is loosely based on the
[2insert.xqm](https://github.com/mblakele/taskbot/blob/master/test/2insert.xqm)
test case. We ask taskbot to insert 100,000 documents
in segments of 500 each. This can be much faster than a single transaction.

    (: This inserts 1M simple test documents.
     : Extend as needed.
     :)
    tb:list-segment-process(
      1 to 1000 * 1000,
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
            ! element asset-ref { xdmp:random(1000) } }),
        xdmp:commit() },
      (: options - not used in this example. :)
      map:new(map:entry('testing', '123...'),
      $tb:OPTIONS-UPDATE)

Important points:

* The segment size is 500, which is a good place to start.
* Do not change the function signature.
** The first parameter is the list of (at most) 500 items to process. In this example, each item will be a number from 1 to 1M.
** The second parameter is a map, which can contain anything you like. In this example it's just a placeholder with `testing: 123...`.
* If your function includes **updates***, remember to call `xdmp:commit` at the end.

### Calculate and persist document relationships

This example is loosely based on the
[3ref.xqm](https://github.com/mblakele/taskbot/blob/master/test/3ref.xqm)
test case. The idea is to calculate and store the relationship
between a give asset document and other asset documents that refer to it.
By persisting this relationship we could use it to build a range index,
and make it available for queries.

    (: In a cluster, start this once on each host.
     : This will create a new task per forest,
     : fanning out from there.
     :)
    for $f in tb:database-host-forests(xdmp:database(), xdmp:host())
    return xdmp:spawn-function(
      tb:forests-uris-process(
        $f,
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
       $tb:OPTIONS-UPDATE))

### Report on existing documents

Sometimes you need to report on what's out there,
but the existing indexes don't support your query
and you don't have time to build new indexes.
Ask taskbot to help. The key here is `$tb:OPTIONS-SYNC`,
which includes the `<result>true</result>` option.
So your work runs on the task server,
but you still get the results back in your query.

This example is loosely based on the
[4results.xqm](https://github.com/mblakele/taskbot/blob/master/test/4results.xqm)
test case. The idea is to calculate the average number
of asset-ref elements per asset document.
We map this work across all forests, in segments of 500 documents each,
then reduce the results.

    (: In a cluster, start this once on each host.
     : This will create a new task per forest,
     : fanning out from there.
     :)
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

## Troubleshooting

Look for messages in ErrorLog.txt, especially after turning up
the `file-log-level` to debug or fine. Write your own messages
using `xdmp:log` or the taskbot log functions.

If you have a bunch of out of control tasks queued,
and don't want to restart the server, call `tb:fatal-set(true())`.
Remember to call `tb:fatal-set(false())` before you try again.
You can protect your own code by calling `tb:maybe-fatal()`,
as in the examples above.

Disappearing updates? Did you remember to call `xdmp:commit()`?

## License Information

Copyright (c) 2014 Michael Blakeley. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

The use of the Apache License does not indicate that this project is
affiliated with the Apache Software Foundation.
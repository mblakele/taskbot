# taskbot

## Introduction

Need to boil an ocean? The taskbot library can help you
put the MarkLogic Task Server to work. Simple map-reduce functions
helps you farm out as many tasks as your MarkLogic cluster
can handle, with as much concurrency as you need.

Get the job done.

Taskbot is basically a map-reduce utility.
Start with an anonymous function, and a list of stuff:
document URIs, or anything else. Taskbot spawns a task
for each segment of the list, using a size you specify.
You provide an anonymous function that processes each segment.
The Task Manager queue and thread pool manage the work,
providing as much data-driven parallelism
as the configuration and the workload allow.

If the anonymous function updates the database, your work is done.
If your function returns results, supply `$tb:OPTIONS-SYNC`
and reduce the results however you like.

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


All that might sound a little too abstract, so here are some examples.

### Creating 1M documents

Inserting one million documents in a single transaction can be painful,
but it's easy with tasks of 500 documents each.

This example is loosely based on the
[2insert.xqm](https://github.com/mblakele/taskbot/blob/master/test/2insert.xqm)
test case. We ask taskbot to insert 1,000,000 documents
in segments of 500 each. This can be much faster than a single transaction.

    (: This inserts 1M simple test documents.
     : Extend as needed.
     :)
    tb:list-segment-process(
      (: Total size of the job. :)
      1 to 1000 * 1000,
      (: Size of each segment of work. :)
      500,
      "test/asset",
      (: This anonymous function will be called for each segment. :)
      function($list as item()+, $opts as map:map?) {
        (: Any chainsaw should have a safety. Check it here. :)
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
        (: This is an update, so be sure to commit each segment. :)
        xdmp:commit() },
      (: options - not used in this example. :)
      map:new(map:entry('testing', '123...')),
      (: This is an update, so be sure to say so. :)
      $tb:OPTIONS-UPDATE)

Important points:

* The segment size is 500, which is a good place to start.
* Do not change the function signature.
    * The first parameter is the list of (at most) 500 items to process. In this example, each item will be a number from 1 to 1M.
    * The second parameter is a map, which can contain anything you like. In this example it's just a placeholder with `testing: 123...`.
* If your function includes **updates**, remember to call `xdmp:commit` at the end.

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

## API

### Module Variables

For your convenience, taskbot exposes some module variables.

#### Options elements in the `xdmp:eval` namespace

* `OPTIONS-PRIORITY`: set <priority>higher</priority>
* `OPTIONS-SAFE`: set `<isolation>different-transaction</isolation>`
  and `<prevent-deadlocks>true</prevent-deadlocks>`. This is useful
  to avoid accidentally starting an update from an update.
* `OPTIONS-SYNC`: set `<result>true</result>`
  and `<priority>higher</priority>`. This is useful when your task
  will return results.
* `OPTIONS-SYNC-UPDATE`: set `<result>true</result>`
  and `<priority>higher</priority>`
  and `<transaction-mode>update</transaction-mode>`.
  This is useful when your task will update and return results.
* `OPTIONS-UPDATE`: set `<transaction-mode>update</transaction-mode>`.
  Use this for any update function, because `xdmp:spawn-function`
  defaults to timestamped mode. Also be sure to call `xdmp:commit`
  at the end of your function.

### Functions

### list-segment-process

```
tb:list-segment-process(
  $list-all as item()*,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  [$fn-options as map:map?],
  [$eval-options as element(eval:options)?],
  [$mode as xs:string],
  [$policy as xs:string?],
  [$sleep as xs:unsignedInt?])
as item()*
```

Apply a function `$fn` across a list of items `$list`,
in segments of `$size` each. The `$label` is an arbitrary string
used for logging.

The function `$fn` must have the correct signature
`function(item()+, map:map?) as item()*`.
This will be called multiple times, each time processing
a segment of `$size` sequential items from `$list`.
Any map is supplied as `$fn-options`,
it will be passed to `$fn` for each segment.

The `$mode` may be `spawn` (default) or `invoke`,
and governs whether each segment is processed using
`xdmp:spawn-function` or `xdmp:invoke-function`.
If `$eval-options` are supplied, they will be passed to the
`xdmp:spawn-function` or `xdmp:invoke-function` call for each segment.

If `$mode` is `spawn` (default), and the call to `xdmp:spawn-function`
throws `XDMP-MAXTASKS`, then the `$policy` will govern behavior.
Policies include:

* `abort`: re-throw the `XDMP-MAXTASKS` error, aborting the work.
* `caller-blocks`: the caller will sleep and try again, using
  incremental back off and retry. The first sleep is 1-ms,
  doubling to a maximum of 1000-ms.
* `caller-runs` (default): the caller will invoke the function immediately.
* `discard`: the segment will be discarded.

If `$sleep` is supplied, taskbot will sleep `$sleep` milliseconds
between segments. This can be useful when the work is low-priority
and might impact production queries unless throttled.

### forests-uris-process

```
tb:forests-uris-process(
  $forests as xs:unsignedLong+,
  $uris-options as xs:string*,
  $query as cts:query?,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  [$fn-options as map:map?],
  [$eval-options as element(eval:options)?])
as item()*
```

This function uses `cts:uris` to list URIs from specific forest(s),
optionally matching `$query` and `$uris-options`.
See [cts:uris](https://docs.marklogic.com/cts:uris) for details
of these options.
The URIs and remaining options are passed to `tb:list-segment-process`
for segmentation and processing.

### fatal-set

```
tb:fatal-set($value as xs:boolean)
as empty-sequence()
```

This function sets the server variable checked by `tb:maybe-fatal`.
Set `true` to stop existing work as quickly as possible,
without restarting MarkLogic.

### maybe-fatal

```
tb:maybe-fatal()
as empty-sequence()
```

This function checks a server field to see if the current operation
has been canceled. If so it will throw `TASKBOT-FATAL`.

#### log

```
tb:log(
  $label as xs:string,
  $list as xs:anyAtomicType*,
  $level as xs:string)
as empty-sequence()
```

Use this function to log messages at an arbitrary level.
The `$label` will automatically gain a `taskbot:` prefix.
The levels are the ones used by [xdmp:log](https://docs.marklogic.com/xdmp:log).

#### fine

```
tb:fine(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
```

Log a message at `level=fine`.
The `$label` will automatically gain a `taskbot:` prefix.

#### debug

```
tb:debug(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
```

Log a message at `level=debug`.
The `$label` will automatically gain a `taskbot:` prefix.

#### info

```
tb:info(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
```

Log a message at `level=info`.
The `$label` will automatically gain a `taskbot:` prefix.

#### warning

```
tb:warning(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
```

Log a message at `level=warning`.
The `$label` will automatically gain a `taskbot:` prefix.

### error

```
tb:error(
  $code as xs:string,
  $items as item()*)
as empty-sequence()
```

Throw an error using [fn:error](https://docs.marklogic.com/fn:error).
The `$code` will automatically gain a `TASKBOT-` prefix.

### assert-timestamp

```
tb:assert-timestamp()
as empty-sequence()
```

Call to ensure that the current evaluation context is read-only,
aka timestamped. If called in an update, it will throw an error
`TASKBOT-NOTIMESTAMP`.

### options-forest

```
tb:options-forest($forest as xs:unsignedLong)
as element(eval:options)
```

Returns an eval options element that can be used to restrict
an operation to a single forest.

### options-forest-update

```
tb:options-forest-update($forest as xs:unsignedLong)
as element(eval:options)
```

Returns an eval options element that can be used to restrict
an update operation to a single forest.

## Troubleshooting

Look for messages in `ErrorLog.txt`, especially after setting
`file-log-level` to debug or fine. Write your own messages
using `xdmp:log` or the taskbot log functions.

If you have a bunch of out of control tasks queued,
and don't want to restart the server, call `tb:fatal-set(true())`.
Remember to call `tb:fatal-set(false())` before you try again.
You can protect your own code by calling `tb:maybe-fatal()`,
as in the examples above.

Disappearing updates? Did you remember to call `xdmp:commit()`
in your anonymous function?

Not seeing enough parallelism?
Is the input list large enough to drive enough tasks?
Do you have enough Task Manager threads configured for your CPU core count?
Experiment with 1-4 threads per CPU core.

## License Information

Copyright (c) 2014 Michael Blakeley. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0]
(http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

The use of the Apache License does not indicate that this project is
affiliated with the Apache Software Foundation.

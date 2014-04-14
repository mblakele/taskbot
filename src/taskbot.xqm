xquery version "1.0-ml";
(:
 : taskbot.xqm
 :
 : Utility library for managing the task server.
 :
 :)
module namespace m="ns://blakeley.com/taskbot" ;

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare namespace eval="xdmp:eval" ;
declare namespace http="xdmp:http" ;

declare namespace mlss="http://marklogic.com/xdmp/status/server" ;

declare variable $ERRORS-URI := $M||'/errors/' ;

declare variable $FATAL-NAME := $M||'/.FATAL' ;
declare variable $FATAL := xdmp:get-server-field($FATAL-NAME) ;

(: SUPPORT-13787 7.0-2.1 xdmp:spawn-function shows parent server.
 : So do not use xdmp:spawn-function.
 :)
declare variable $IS-TASKSERVER as xs:boolean := ($SERVER eq 'TaskServer') ;

declare variable $M := namespace-uri(<m:x/>) ;

(: Limit input list size, for fast subsequence calls. :)
declare variable $MAX-LIMIT := 500 ;

(: Limit backoff and retry. :)
declare variable $MAX-SLEEP := 1000 ;

declare variable $OPTIONS-PRIORITY := (
  <options xmlns="xdmp:eval">
    <priority>higher</priority>
  </options>
);

declare variable $OPTIONS-SAFE := (
  <options xmlns="xdmp:eval">
    <isolation>different-transaction</isolation>
    <prevent-deadlocks>true</prevent-deadlocks>
  </options>
);

declare variable $OPTIONS-SYNC := (
  <options xmlns="xdmp:eval">
    <result>true</result>
    <priority>higher</priority>
  </options>
);

declare variable $OPTIONS-UPDATE := (
  <options xmlns="xdmp:eval">
    <transaction-mode>update</transaction-mode>
  </options>
);

declare variable $SERVER := xdmp:server-name(xdmp:server()) ;

(: When no transform function is supplied, use an identity function. :)
declare variable $TRANSFORM-DEFAULT := function(
  $content as node(),
  $uri as xs:string) as node() { $content } ;

declare function m:log(
  $label as xs:string,
  $list as xs:anyAtomicType*,
  $level as xs:string)
as empty-sequence()
{
  xdmp:log(text { '[taskbot:'||$label||']', $list }, $level)
};

declare function m:fine(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  m:log($label, $list, 'fine')
};

declare function m:debug(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  m:log($label, $list, 'debug')
};

declare function m:info(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  m:log($label, $list, 'info')
};

declare function m:warning(
  $label as xs:string,
  $list as xs:anyAtomicType*)
as empty-sequence()
{
  m:log($label, $list, 'warning')
};

declare function m:error(
  $code as xs:string,
  $items as item()*)
as empty-sequence()
{
  error((), 'TASKBOT-'||$code, $items)
};

declare function m:assert-timestamp()
as empty-sequence()
{
  if (xdmp:request-timestamp()) then ()
  else m:error(
    'NOTIMESTAMP',
    text {
      'Request should be read-only but has no timestamp.',
      'Check the code path for update functions.' })
};

declare function m:fatal-set($value as xs:boolean)
 as empty-sequence()
{
  m:info(
    'fatal-set',
    (: Take advantage of set-server-field return value. :)
    xdmp:set-server-field($FATAL-NAME, $value)),
  xdmp:set($FATAL, $value)
};

declare function m:maybe-fatal()
as empty-sequence()
{
  (: The server field is only visible from the task server.
   : If on another server, spawn a task to call this function.
   :)
  if (not($IS-TASKSERVER)) then xdmp:spawn(
    'maybe-fatal.xqy', (), $OPTIONS-SYNC)
  else if (not($FATAL)) then ()
  else m:error('FATAL', 'FATAL is set: stopping')
};

declare function m:options-forest(
  $forest as xs:unsignedLong)
as element()
{
  <options xmlns="xdmp:eval">
    <database>{ $forest }</database>
  </options>
};

declare function m:options-update-forest(
  $forest as xs:unsignedLong)
as element()
{
  <options xmlns="xdmp:eval">
    <transaction-mode>update</transaction-mode>
    <database>{ $forest }</database>
  </options>
};

declare function m:spawn-function-with-policy(
  $fn as function() as item()*,
  $eval-options as element(eval:options)?,
  $policy as xs:string?,
  $sleep as xs:integer)
as item()*
{
  m:maybe-fatal(),
  m:debug(
    'spawn-function-with-policy',
    ('function', xdmp:describe($fn),
      'eval-options', xdmp:describe($eval-options),
      $policy, $sleep)),
  try {
    xdmp:spawn-function($fn, $eval-options) }
  catch($ex) {
    if ($ex/error:code ne 'XDMP-MAXTASKS') then xdmp:rethrow()
    else switch($policy)
    case 'abort' return xdmp:rethrow()
    case 'caller-blocks' return (
      (: Back off and retry, with a cap. :)
      xdmp:sleep($sleep),
      m:spawn-function-with-policy(
        $fn, $eval-options, $policy,
        min((2 * $sleep, $MAX-SLEEP))))
    case 'caller-runs' return xdmp:invoke-function($fn, $eval-options)
    case 'discard' return m:info(
      'spawn-function-with-policy',
      ('discarding task', xdmp:describe($fn), 'due to XDMP-MAXTASKS'))
    default return m:error(
      'BADPOLICY',
      ('supported policies are:',
        '"abort", "caller-runs", "caller-blocks", "discard"'))
  }
};

declare function m:spawn-function-with-policy(
  $fn as function() as item()*,
  $eval-options as element(eval:options)?,
  $policy as xs:string?)
as item()*
{
  m:spawn-function-with-policy(
    $fn, $eval-options, $policy, 1)
};

(: The input list should be small.
 : Usually this is called by list-segment-process.
 :)
declare function m:segment-process(
  $label as xs:string,
  $fn as function() as item()*,
  $eval-options as element(eval:options)?,
  $mode as xs:string,
  $policy as xs:string?)
as item()*
{
  m:maybe-fatal(),
  m:debug('segment-process', ($label, $mode, $policy)),
  switch($mode)
  case 'invoke' return xdmp:invoke-function(
    $fn, $eval-options)
  case 'spawn' return m:spawn-function-with-policy(
    $fn, $eval-options, $policy)
  default return m:error(
    'BADMODE', ($mode, 'must be spawn or invoke'))
};

(: Break up large lists into segments,
 : and process each segment.
 : This can be used as an entry point.
 :)
declare function m:list-segment-process(
  $list-all as item()*,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  $fn-options as map:map?,
  $eval-options as element(eval:options)?,
  $mode as xs:string,
  $policy as xs:string?,
  $sleep as xs:unsignedInt?)
as item()*
{
  m:maybe-fatal(),
  let $count := count($list-all)
  let $_ := m:info(
    'list-segment-process',
    ($label, 'count', $count, $size, $mode, $policy))
  let $limit := ceiling($count div $size)
  return (
    if ($limit gt $MAX-LIMIT) then (
      (: Split it in two up front. This ends up being faster. :)
      m:debug(
        'list-segment-process', ('splitting', $count, $count idiv 2)),
      m:list-segment-process(
        subsequence($list-all, 1, $count idiv 2),
        $size, $label,
        $fn, $fn-options,
        $eval-options, $mode, $policy, $sleep),
      m:list-segment-process(
        subsequence($list-all, 1 + $count idiv 2),
        $size, $label,
        $fn, $fn-options,
        $eval-options, $mode, $policy, $sleep))
    else (
      for $step in 1 to $limit
      let $_ := m:maybe-fatal()
      let $start := 1 + $size * ($step - 1)
      let $_ := m:info(
        'segment-process',
        ($label, $step||'/'||$limit, $start||'/'||$count))
      let $list-step := subsequence($list-all, $start, $size)
      return (
        m:segment-process(
          $label||'['||$step||']',
          function() as item()* { $fn($list-step, $fn-options) },
          $eval-options, $mode, $policy),
        (: Optionally throttle the work. :)
        if (not($sleep)) then ()
        else xdmp:sleep($sleep)),
      m:info(
        'list-segment-process',
        ('processed', $label, $count, $size, xdmp:elapsed-time()))))
};

(:
 : Shortcut when the caller does not want to specify some options.
 : This can be used as an entry point.
 :)
declare function m:list-segment-process(
  $list-all as item()*,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  $fn-options as map:map?,
  $eval-options as element(eval:options)?)
as item()*
{
  m:list-segment-process(
    $list-all, $size, $label,
    $fn, $fn-options, $eval-options,
    'spawn', 'caller-runs', ())
};

(:
 : Shortcut when the caller does not want to specify some options.
 : This can be used as an entry point.
 :)
declare function m:list-segment-process(
  $list-all as item()*,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  $fn-options as map:map?)
as item()*
{
  m:list-segment-process(
    $list-all, $size, $label,
    $fn, $fn-options, ())
};

(:
 : Shortcut when the caller does not want to specify some options.
 : This can be used as an entry point.
 :)
declare function m:list-segment-process(
  $list-all as item()*,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*)
as item()*
{
  m:list-segment-process(
    $list-all, $size, $label,
    $fn, ())
};

declare function m:database-host-forests(
  $database as xs:unsignedLong,
  $host as xs:unsignedLong)
as xs:unsignedLong*
{
  let $host-forests := xdmp:host-forests(xdmp:host())
  return xdmp:database-forests(xdmp:database())[ . = $host-forests ]
};

declare function m:forests-uris-process(
  $forests as xs:unsignedLong+,
  $uris-options as xs:string*,
  $query as cts:query?,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  $fn-options as map:map?,
  $eval-options as element(eval:options)?)
as item()*
{
  m:maybe-fatal(),
  m:info(
    'forest-uris-process',
    ('starting', xdmp:forest-name($forests), $query, $size, $label)),
  (: Feed URIs to segment processing. :)
  m:list-segment-process(
    cts:uris((), $uris-options, $query, (), $forests),
    $size, $label, $fn,
    map:new(
      ($fn-options,
        map:entry('forests', $forests),
        map:entry('size', $size))),
    $eval-options)
};

declare function m:forests-uris-process(
  $forests as xs:unsignedLong+,
  $uris-options as xs:string*,
  $query as cts:query?,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*,
  $fn-options as map:map?)
as item()*
{
  m:forests-uris-process(
    $forests, $uris-options, $query,
    $size, $label,
    $fn, $fn-options, ())
};

declare function m:forests-uris-process(
  $forests as xs:unsignedLong+,
  $uris-options as xs:string*,
  $query as cts:query?,
  $size as xs:integer,
  $label as xs:string,
  $fn as function(item()+, map:map?) as item()*)
as item()*
{
  m:forests-uris-process(
    $forests, $uris-options, $query,
    $size, $label,
    $fn, ())
};

(: Instead of throwing an error when work fails,
 : log the message and insert an error document.
 : This is useful for transient errors, eg S3 service problems.
 :)
declare function m:ingestion-error(
  $bucket as xs:string,
  $key as xs:string,
  $ex as element(error:error))
as empty-sequence()
{
  m:warning('ingestion-error', ($key, xdmp:quote($ex))),
  xdmp:document-insert(
    $ERRORS-URI||$bucket||'/'||$key,
    $ex)
};

declare function m:error-uris()
as xs:string*
{
  cts:uris((), (), cts:directory-query($ERRORS-URI, 'infinity'))
};

declare function m:uri-by-assignment(
  $uri as xs:string,
  $database-forest-count as xs:integer,
  $host-forest-indexes as xs:integer+)
as xs:string?
{
  if (xdmp:document-assign($uri, $database-forest-count)
    = $host-forest-indexes) then $uri
  else ()
};

(: Given a list of uris, filter by assignment.
 : This is useful when you want a host to process
 : only the documents that belong there.
 :)
declare function m:uri-list-by-assignment(
  $list as xs:string+,
  $database-forests as xs:unsignedLong+,
  $host-forests as xs:unsignedLong+)
as xs:string*
{
  (: Function mapping list-to-uri. :)
  m:uri-by-assignment(
    $list,
    count($database-forests),
    $host-forests ! index-of($database-forests, .))
};

declare function m:tasks-count()
as xs:integer
{
  count(
    xdmp:server-status(xdmp:hosts(), xdmp:server('TaskServer'))
    /mlss:server-status/mlss:request-statuses/mlss:request-status)
};

declare function m:fn-wait(
  $label as xs:string,
  $fn as function() as xs:boolean,
  $sleep as xs:integer)
as empty-sequence()
{
  m:debug('fn-wait', ($label, $sleep)),
  if ($fn()) then () else (
    (: Back off and retry, with a cap. :)
    xdmp:sleep($sleep),
    m:fn-wait($label, $fn, min((2 * $sleep, $MAX-SLEEP))))
};

declare function m:fn-wait(
  $label as xs:string,
  $fn as function() as xs:boolean)
as empty-sequence()
{
  m:fn-wait($label, $fn, 1)
};

declare function m:tasks-wait(
  $count as xs:integer)
as empty-sequence()
{
  m:fn-wait(
    'tasks-wait',
    function() as xs:boolean { m:tasks-count() le $count })
};

declare function m:tasks-wait()
as empty-sequence()
{
  m:tasks-wait(0)
};

(: src/taskbot.xqm :)
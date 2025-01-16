xquery version "3.1";

module namespace mrcviewapi="http://teipublisher.com/api/mrcviewapi";

import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace router="http://e-editiones.org/roaster";
import module namespace dapi="http://teipublisher.com/api/documents" at "lib/api/document.xql";
import module namespace rutil="http://e-editiones.org/roaster/util";

import module namespace pages="http://www.tei-c.org/tei-simple/pages" at "lib/pages.xql";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "lib/util.xql";
import module namespace nav="http://www.tei-c.org/tei-simple/navigation" at "/navigation.xql";
import module namespace nav-tei="http://www.tei-c.org/tei-simple/navigation/tei" at "navigation-tei.xql";
import module namespace query="http://www.tei-c.org/tei-simple/query" at "query.xql";
import module namespace mapping="http://www.tei-c.org/tei-simple/components/map" at "map.xql";

declare namespace tei="http://www.tei-c.org/ns/1.0";


declare function mrcviewapi:root_id_bk($request as map(*)){
    if($request?parameters?path) then
        let $doc := doc("/db/apps/tei-publisher/data/" || xmldb:decode($request?parameters?document))
        let $xquery := " $doc" ||"//"|| $request?parameters?path
            return map {
                    "root_id": util:node-id(util:eval($xquery))
                }
                (:  "content": $doc :)
    else return  
};

declare function mrcviewapi:root_id($request as map(*)){
   
    let $doc := doc("/db/apps/tei-publisher/data/" || xmldb:decode($request?parameters?document))
        for $xpath in $request?parameters?path 
            return map {
                "xpath": $xpath,
              "root_id": 
                    let $xquery := " $doc" ||"//"|| $xpath
                    return util:node-id(util:eval($xquery))
            }
};

declare function mrcviewapi:root_id_remote($request as map(*)){
   
    let $doc := doc(xmldb:decode($request?parameters?document))
        for $xpath in $request?parameters?path 
            return map {
                "xpath": $xpath,
              "root_id": 
                    let $xquery := " $doc" ||"//"|| $xpath
                    return util:node-id(util:eval($xquery))
            }
};

declare function mrcviewapi:load-xml($view as xs:string?, $root as xs:string?, $doc as xs:string, $url as xs:string) {
    if($url) then 
        for $data in mrcviewapi:get-document("",$url)
        return
            if (exists($data)) then
                mrcviewapi:load-xml($data, $view, $root, $doc,"" )
            else
                ()
    else 
        for $data in mrcviewapi:get-document("",$doc)
        return
            if (exists($data)) then
                pages:load-xml($data, $view, $root, $doc)
            else
                ()
};

declare function mrcviewapi:load-xml($data as node()*, $view as xs:string?, $root as xs:string?, $doc as xs:string,  $none as xs:string?) {
    let $config :=
        (: parse processing instructions and remember original context :)
        map:merge((tpu:parse-pi(root($data[1]), $view), map { "context": $data }))
    return
        map {
            "config": $config,
            "data":
                switch ($config?view)
            	    case "div" return
                        if ($root) then
                            let $node := util:node-by-id($data/tei:TEI, $root)
                            return
                                nav:get-section-for-node($config, $node)
                        else
                            nav:get-section($config, $data)
                    case "page" return
                        if ($root) then
                            util:node-by-id($data/tei:TEI, $root)
                        else
                            nav:get-first-page-start($config, $data)
                    case "single" return
                        if ($root) then
                            util:node-by-id($data/tei:TEI, $root)
                        else
                            $data
                    default return
                        if ($root) then
                            util:node-by-id($data/tei:TEI, $root)
                        else
                            $data/tei:TEI/tei:text
        }
};


declare function mrcviewapi:get-document($idOrName as xs:string, $url as xs:string?) {
    if ($url) then
        doc($url)
    else if (starts-with($idOrName, '/')) then
        doc(xmldb:encode-uri($idOrName))
    else
        doc(xmldb:encode-uri($config:data-root || "/" || $idOrName))
};

 
declare function mrcviewapi:get-document($idOrName as xs:string) {
    if ($config:address-by-id) then
        root(collection($config:data-root)/id($idOrName))
    else if (starts-with($idOrName, '/')) then
        doc(xmldb:encode-uri($idOrName))
    else
        doc(xmldb:encode-uri($config:data-root || "/" || $idOrName))
};

declare function mrcviewapi:get-xml($request as map(*)) {
     doc($request?parameters?url)
};
 declare function mrcviewapi:get-fragment_test($request as map(*)) {
     $request?parameters?user.url
 };
declare function mrcviewapi:get-fragment($request as map(*)) {
    let $doc := xmldb:decode-uri($request?parameters?doc)
    let $view := head(($request?parameters?view, $config:default-view))
    let $xmlTmp :=
        if ($request?parameters?xpath) then
            for $document in mrcviewapi:get-document($doc)
            let $namespace := namespace-uri-from-QName(node-name($document/*))
            let $xquery := "declare default element namespace '" || $namespace || "'; $document" || $request?parameters?xpath
            let $data := util:eval($xquery)
            return
                if ($data) then
                    pages:load-xml($data, $view, $request?parameters?root, $doc)
                else
                    ()

        else if (exists($request?parameters?id)) then (
            for $document in mrcviewapi:get-document($doc)
            let $config := tpu:parse-pi($document, $view)
            let $data :=
                if (count($request?parameters?id) = 1) then
                    nav:get-section-for-node($config, $document/id($request?parameters?id))
                else
                    let $ms1 := $document/id($request?parameters?id[1])
                    let $ms2 := $document/id($request?parameters?id[2])
                    return
                        if ($ms1 and $ms2) then
                            nav-tei:milestone-chunk($ms1, $ms2, $document/tei:TEI)
                        else
                            ()
            return
                map {
                    "config": map:merge(($config, map { "context": $document })),
                    "odd": $config?odd,
                    "view": $config?view,
                    "data": $data
                }
        ) else
            if($request?parameters?user.url) then
                mrcviewapi:load-xml($view, $request?parameters?root, $doc, $request?parameters?user.url)
            else
                pages:load-xml($view, $request?parameters?root, $doc)
     let $xml := 
        if ($xmlTmp?data) then $xmlTmp
        else 
            pages:load-xml($view, '', $doc)
    return
        if ($xml?data) then
            let $userParams :=
                map:merge((
                    request:get-parameter-names()[starts-with(., 'user')] ! map { substring-after(., 'user.'): request:get-parameter(., ()) },
                    map { "webcomponents": 7 }
                ))
            let $mapped :=
                if ($request?parameters?map) then
                    let $mapFun := function-lookup(xs:QName("mapping:" || $request?parameters?map), 3)
                    let $mapped := $mapFun($xml?data, $userParams,  $request?parameters)
                    return
                        $mapped
                else
                    $xml?data
            let $data :=
                if (empty($request?parameters?xpath) and $request?parameters?highlight and exists(session:get-attribute($config:session-prefix || ".query"))) then
                    query:expand($xml?config, $mapped)[1]
                else
                    $mapped
            let $content :=
                if (not($view = "single")) then
                    pages:get-content($xml?config, $data)
                else
                    $data

            let $html :=
                typeswitch ($mapped)
                    case element() | document-node() return
                        pages:process-content($content, $xml?data, $xml?config, $userParams)
                    default return
                        $content
            let $transformed := dapi:extract-footnotes($html[1])
            let $doc := replace($doc, "^.*/([^/]+)$", "$1")
            return
                if ($request?parameters?format = "html") then
                    router:response(200, "text/html", $transformed?content)
                else
                    let $next := if ($view = "single") then () else $config:next-page($xml?config, $xml?data, $view)
                    let $prev := if ($view = "single") then () else $config:previous-page($xml?config, $xml?data, $view)
                    return
                        router:response(200, "application/json",
                            map {
                                "format": $request?parameters?format,
                                "view": $view,
                                "doc": $doc,
                                "root": $request?parameters?root,
                                "odd": $xml?config?odd,
                                "next":
                                    if ($next) then
                                        util:node-id($next)
                                    else (),
                                "previous":
                                    if ($prev) then
                                        util:node-id($prev)
                                    else
                                        (),
                                "nextId": 
                                    if ($next) then
                                        $next/@xml:id/string()
                                    else (),
                                "previousId":
                                    if ($prev) then
                                        $prev/@xml:id/string()
                                    else
                                        (),
                                "switchView":
                                    if ($view != "single") then
                                        let $node := pages:switch-view-id($xml?data, $view)
                                        return
                                            if ($node) then
                                                util:node-id($node)
                                            else
                                                ()
                                    else
                                        (),
                                "content": serialize($transformed?content,
                                    <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                                    <output:indent>no</output:indent>
                                    <output:method>html5</output:method>
                                        </output:serialization-parameters>),
                                "footnotes": $transformed?footnotes,
                                "userParams": $userParams,
                                "collection": dapi:get-collection($xml?data[1])
                            }
                        )
        else
            error($errors:NOT_FOUND, "Document " || $doc || " not found")
};

(:~ 
 : Get page/div nodes from XML document based on view type
 : @param $data The XML document
 : @param $view The current view ("page" or "div")
 : @return array of maps containing node IDs and page numbers
 :)
declare function mrcviewapi:get-document-nodes($data as node(), $view as xs:string) {
    if ($view = "page") then
        let $allPbs := root($data)//tei:pb
        return
            array {
                for $pb in $allPbs
                return map {
                    "id": util:node-id($pb),
                    "n": $pb/@n/string(),
                    "xmlId": $pb/@xml:id/string()
                }
            }
    else if ($view = "div") then
        let $allDivs := root($data)//tei:div
        return
            array {
                for $div in $allDivs
                return map {
                    "id": util:node-id($div),
                    "n": $div/@n/string()
                }
            }
    else ()
};

declare function mrcviewapi:get-fragment-from-xml($request as map(*)) {
    let $doc := $request?parameters?user.url
    let $includePages :=  $request?parameters?user.includePages = "true"
    let $root := $request?parameters?root
    let $view := head(($request?parameters?view, $config:default-view))
    let $file := request:get-uploaded-file-data("file")
    let $decodedXml := util:base64-decode($file) 
    let $xmlNodes := 
        try {
            parse-xml($decodedXml)
        } catch * {
            router:response(400, "application/json",
                map {
                    "status": "error",
                    "message": "Failed to parse XML: " || $err:description
                }
            )
        }
    let $fragment :=
         if (exists($request?parameters?id)) then (
            let $rootNode := root($xmlNodes)
            let $config := tpu:parse-pi($rootNode, $view)
            let $data :=
                if (count($request?parameters?id) = 1) then
                    nav:get-section-for-node($config, $rootNode/id($request?parameters?id))
                else
                    let $ms1 := $rootNode/id($request?parameters?id[1])
                    let $ms2 := $rootNode/id($request?parameters?id[2])
                    return
                        if ($ms1 and $ms2) then
                            nav-tei:milestone-chunk($ms1, $ms2, $rootNode/tei:TEI)
                        else
                            ()
            return
                map {
                    "config": map:merge(($config, map { "context": $rootNode })),
                    "odd": $request?odd,
                    "view": $view,
                    "data": $data
                }
        ) else
           mrcviewapi:load-xml($xmlNodes, $view,$root, $doc , "")
    return
        if ($fragment?data) then
            let $pages := 
                if ($includePages) then 
                    mrcviewapi:get-document-nodes($xmlNodes, $view)
                else ()
            let $userParams :=
                map:merge((
                    request:get-parameter-names()[starts-with(., 'user')] ! map { substring-after(., 'user.'): request:get-parameter(., ()) },
                    map { "webcomponents": 7 }
                ))
            let $mapped :=
                if ($request?parameters?map) then
                    let $mapFun := function-lookup(xs:QName("mapping:" || $request?parameters?map), 3)
                    let $mapped := $mapFun($fragment?data, $userParams,  $request)
                    return
                        $mapped
                else
                    $fragment?data
            let $data :=
                if (empty($request?parameters?xpath) and $request?parameters?highlight and exists(session:get-attribute($config:session-prefix || ".query"))) then
                    query:expand($fragment?config, $mapped)[1]
                else
                    $mapped
            let $content :=
                if (not($view = "single")) then
                    pages:get-content($fragment?config, $data)
                else
                    $xmlNodes

            let $html :=
                typeswitch ($mapped)
                    case element() | document-node() return
                        pages:process-content($content, $fragment?data, $fragment?config, $userParams)
                    default return
                        $content
            let $transformed := dapi:extract-footnotes($html[1])
            let $doc := replace($doc, "^.*/([^/]+)$", "$1")
            return
                if ($request?parameters?format = "html") then
                    router:response(200, "text/html", $transformed?content)
                else
                    let $next := if ($view = "single") then () else $config:next-page($fragment?config, $fragment?data, $view)
                    let $prev := if ($view = "single") then () else $config:previous-page($fragment?config, $fragment?data, $view)
                    return
                        router:response(200, "application/json",
                            map {
                                "pages": $pages,
                                "format": $request?parameters?format,
                                "view": $view,
                                "doc": $doc,
                                "root": $request?parameters?root,
                                "odd": $fragment?config?odd,
                                "next":
                                    if ($next) then
                                        util:node-id($next)
                                    else (),
                                "previous":
                                    if ($prev) then
                                        util:node-id($prev)
                                    else
                                        (),
                            (:~     "nextId": 
                                    if ($next) then
                                        $next/@xml:id/string()
                                    else (),
                                "previousId":
                                    if ($prev) then
                                        $prev/@xml:id/string()
                                    else
                                        (),:)
                                "switchView":
                                    if ($view != "single") then
                                        let $node := pages:switch-view-id($fragment?data, $view)
                                        return
                                            if ($node) then
                                                util:node-id($node)
                                            else
                                                ()
                                    else
                                        (),
                                "content": serialize($transformed?content,
                                    <output:serialization-parameters xmlns:output="http://www.w3.org/2010/xslt-xquery-serialization">
                                    <output:indent>no</output:indent>
                                    <output:method>html5</output:method>
                                        </output:serialization-parameters>),
                                "footnotes": $transformed?footnotes,
                                "userParams": $userParams,
                                "collection": dapi:get-collection($fragment?data[1])
                        }
                )
        else
            error($errors:NOT_FOUND, "Document " || $doc || " not found")
};

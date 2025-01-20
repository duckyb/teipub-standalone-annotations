xquery version "3.1";

module namespace standalone-anno="http://teipublisher.com/api/standalone-annotations";

declare namespace tei="http://www.tei-c.org/ns/1.0";

import module namespace router="http://e-editiones.org/roaster";
import module namespace errors = "http://e-editiones.org/roaster/errors";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace annocfg = "http://teipublisher.com/api/annotations/config" at "annotation-config.xqm";
import module namespace anno="http://teipublisher.com/api/annotations" at "lib/api/annotations.xql";

(:~
 : Get XML document from either an uploaded file or a URL
 :)
declare function standalone-anno:get-document($request as map(*)) {
    let $file := request:get-uploaded-file-data("file")
    let $url := request:get-parameter("url", ())
    return
        if (exists($file)) then
            let $decodedXml := util:base64-decode($file)
            let $stored := xmldb:store('annotate/temp.xml', 'temp.xml', $decodedXml)
            let $storedDoc := doc($stored)
            return $storedDoc
            (:~ return
                try {
                    let $cleaned := replace($storedDoc, '<\?[^?]*\?>', '')
                    let $parsed := parse-xml($cleaned) => annocfg:fix-namespaces()
                    let $parsed := document { parse-xml($cleaned) => annocfg:fix-namespaces() } 
                    return $parsed
                } catch * {
                    error($errors:BAD_REQUEST, "Failed to parse XML from file: " || $err:description)
                } ~:)
        else if (exists($url)) then
            try {
                doc($url) => annocfg:fix-namespaces()
            } catch * {
                error($errors:NOT_FOUND, "Could not retrieve document from URL: " || $url)
            }
        else
            error($errors:BAD_REQUEST, "Either file or URL must be provided")
};

(:~
 : Save annotations for a standalone document
 :)
declare function standalone-anno:save($request as map(*)) {
    let $body := $request?body
    let $annotations := $body?annotations
    let $srcDoc := standalone-anno:get-document($request)
    return
        if (not($srcDoc)) then
            error($errors:NOT_FOUND, "Document not found")
        else
            let $doc := util:expand($srcDoc/*, 'add-exist-id=all')
            let $map := map:merge(
                let $parsedAnnotations := parse-json($annotations)
                for $annoGroup in $parsedAnnotations?*
                group by $id := $annoGroup?context
                let $node := $doc//*[@exist:id = $id]
                where exists($node)
                let $ordered :=
                    for $anno in $annoGroup
                    order by anno:order($anno?type) ascending
                    return $anno
                return
                    map:entry($id, anno:apply($node, $ordered))
            )
            let $merged := anno:merge($doc, $map) => anno:strip-exist-id() => anno:revision($body?log)
            let $output := document {
                $srcDoc/(processing-instruction()|comment()),
                $merged
            }
            return
                map {
                    "srcDoc": $srcDoc,
                    "doc": $doc,
                    "content": serialize($output, map { "indent": false() }),
                    "changes": array { $map?* ! anno:strip-exist-id(.) },
                    "remote": true()
                }
};

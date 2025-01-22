xquery version "3.1";

module namespace test = "http://teipublisher.com/api/test";

import module namespace util = "http://exist-db.org/xquery/util";
import module namespace xmldb = "http://exist-db.org/xquery/xmldb";
import module namespace config="http://www.tei-c.org/tei-simple/config" at "../../config.xqm";
import module namespace anno = "http://teipublisher.com/api/annotations" at "lib/api/annotations.xql";
(:~ let $collections := xmldb:match-collection("\*") ~:)

declare function test:execute($request as map(*)) {
    (:~ read query parameters ~:)
    let $body := $request?body
    let $annotations := $body?annotations
    
    (:~ decode the uploaded file ~:)
    let $file := request:get-uploaded-file-data("file")
    let $decodedXml := util:base64-decode($file)
    
    (:~ decode the annotations ~:)
    let $parsedAnnotations := parse-json($annotations)

    (:~ select a collection to store the temporary file ~:)
    let $basePath := "/db/apps/tei-publisher/data/"
    let $collectionName := 'annotate'
    let $collectionURI := $basePath || $collectionName

    (:~ create a new temporary file with a random name ~:)
    let $uid := util:uuid()
    let $documentURI := xmldb:store($collectionURI, $uid || '.xml', $decodedXml)
    let $storedDocument := config:get-document($documentURI)

    (:~ call the original anno:merge-and-save ~:)
    let $result := anno:merge-and-save($storedDocument, $documentURI, $parsedAnnotations, $body?log)
    
    (:~ delete the temporary file ~:)
    let $rm := xmldb:remove($collectionURI, $uid || '.xml')
    
    return $result
};

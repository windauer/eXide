(:
 :  eXide - web-based XQuery IDE
 :
 :  Copyright (C) 2013 Wolfgang Meier
 :
 :  This program is free software: you can redistribute it and/or modify
 :  it under the terms of the GNU General Public License as published by
 :  the Free Software Foundation, either version 3 of the License, or
 :  (at your option) any later version.
 :
 :  This program is distributed in the hope that it will be useful,
 :  but WITHOUT ANY WARRANTY; without even the implied warranty of
 :  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 :  GNU General Public License for more details.
 :
 :  You should have received a copy of the GNU General Public License
 :  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 :)
xquery version "3.0";


declare option exist:serialize "method=json media-type=text/javascript";

declare variable $local:store-as-binary := function-lookup(xs:QName("xmldb:store-as-binary"), 3);

declare function local:fix-permissions($collection as xs:string, $resource as xs:string) {
    let $path := concat($collection, "/", $resource)
    let $mime := xmldb:get-mime-type($path)
    return
        if ($mime eq "application/xquery") then
            sm:chmod(xs:anyURI($path), "u+x,g+x,o+x")
        else
            ()
};

declare function local:get-run-path($path) {
    let $appRoot := repo:get-root()
    return
        replace(
            if (starts-with($path, $appRoot)) then
                request:get-context-path() || "/" || request:get-attribute("$exist:prefix") || "/" ||
                substring-after($path, $appRoot)
            else
                request:get-context-path() || "/rest" || $path,
            "/{2,}", "/"
        )
};

declare function local:get-mime-type() {
    let $contentType := request:get-header("Content-Type")
    return
        replace($contentType, "\s*;.*$", "")
};

(:~ Called by the editor to store a document :)

let $path := request:get-parameter("path", ())
let $split := analyze-string($path, "^(.*)/([^/]+)$")//fn:group/string()
let $collection := xmldb:encode-uri($split[1])
let $resource := xmldb:encode-uri($split[2])
let $mime := local:get-mime-type()
let $data := request:get-data()
let $data :=
    if($data instance of xs:base64Binary) then
        $data
    else if($mime and not($data)) then
        util:string-to-binary("")
    else
        $data
return
        try {
            let $isNew := not(util:binary-doc-available($path)) and not(doc-available($path))
            let $path :=
                if(util:binary-doc-available($path) and exists($local:store-as-binary)) then
                    $local:store-as-binary($collection, $resource, $data)
                else
                    if ($mime) then
                        xmldb:store($collection, $resource, $data, $mime)
                    else
                        xmldb:store($collection, $resource, $data)
            return (
                if ($isNew) then
                    local:fix-permissions($collection, $resource)
                else
                    (),
                <message status="ok" externalLink="{local:get-run-path($path)}"/>
            )
        } catch * {
            let $message :=
            replace(
                replace($err:description, "^.*XMLDBException:", ""),
                "\[at.*\]$", ""
            )
            return
                <error status="error">
                    <message>{$message}</message>
                </error>
        }

package webdav

import encoding.xml.{SaxHandler, XmlAttr}
import std.collection.ArrayList
import std.io.InputStream

public func fixSlash(s:String):String {
    if (s.endsWith("/")) {
        return s
    }
    return s + "/"
}

public func fixSlashes(s:String):String {
    var ss = s 
    if (!ss.startsWith("/")) {
        ss = "/" + ss
    }
    return fixSlash(ss)
}

class ResponseHandler <: SaxHandler{
    var curtag = ""
    let responses = ArrayList<WebdavResponse>()
    var currresp:?WebdavResponse = None
    var currProp:?Props = None
    public func startDocument(): Unit {
    }
    public func endDocument(): Unit {
    }
    public func startElement(name: String, attrs: ArrayList<XmlAttr>): Unit {
        this.curtag = name
        match (name) {
            case "D:response" => 
             this.currresp = WebdavResponse("", ArrayList())
            case "D:propstat" =>
               this.currProp = Props()
            case _ => ()
        }
    }
    public func endElement(name: String): Unit {
        match (name) {
            case "D:response" => 
             ifSome(this.currresp, {v => this.responses.append(v)})
            case "D:propstat" =>
               ifSome(this.currProp, { v=> this.currresp?.props.append(v)})
            case "D:collection" => this.currProp?.isDir = true
            case _ => ()
        }
    }
    public func characters(content: String): Unit {
        match (this.curtag) {
            case "D:href" => this.currresp?.href = content
            case "D:displayname" => this.currProp?.name = content
            case "D:getetag" => this.currProp?.etag = content
            case "D:getcontentlength" => this.currProp?.size = content
            case "D:getlastmodified" => this.currProp?.modified = content
            case "D:getcontenttype" => this.currProp?.contentType = content
            case "D:status" => this.currProp?.status = content
            case _ => ()
        }
    }
}

func readAll(input:InputStream):Array<Byte> {
    var bs = ArrayList<Byte>()
    while (true) {
        var buf = Array<Byte>(1024, item: 0)
        let size = input.read(buf)
        bs.appendAll(buf[..size])
        if (size < 1024) {
            break
        }
    }
    return bs.toArray()
}
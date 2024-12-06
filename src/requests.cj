package webdav

import net.http.{HttpRequest, HttpResponse, HttpResponseBuilder, HttpRequestBuilder}
import encoding.url.URL
import std.collection.ArrayList
import std.fs.Path
import std.io.{InputStream, ByteArrayStream, OutputStream, StringReader}
import encoding.xml.XmlParser

extend WebdavClient {
    func req(method: String, path: String, body: Option<InputStream>, interceptor: Option<(req: HttpRequest) -> Unit>): HttpResponse {
        var res: HttpResponse = HttpResponseBuilder().build()
        let (auth, _) = this.auth.newAuthenticator(body)
        var uri = URL.parse(this.root)
        uri = uri.replace(path: URL.mergePaths(uri.path, path))
        var retry = 0
        while (true) {
            if (retry > this.retry) {
                break
            }
            let builder = HttpRequestBuilder().method(method).url(uri).addHeaders(this.headers)
            if (let Some(v) <- body) {
                builder.header("transfer-encoding", "chunked")
                builder.body(v)
            }
            let req = builder.build()
            auth.authorize(this.c, req, path)
            ifSome(interceptor, {fn => fn(req)})
            this.interceptor?(method, req)
            res = this.c.send(req)
            let redo = auth.verify(this.c, res, path)
            if (redo) {
                retry += 1
                continue
            }
            break
        }
        return res
    }
    func options(path: String): HttpResponse {
        return this.req(
            "OPTIONS",
            path,
            None,
            {
                r: HttpRequest =>
                r.headers.add("Depth", "0")
                return
            }
        )
    }
    func mkcol(path: String): UInt16 {
        let res = this.req("MKCOL", path, None, None)
        var status = res.status
        if (status == 405) {
            status = 201
        }
        return status
    }
    func propfind(path: String, self: Bool, body: String): ArrayList<WebdavResponse> {
        var buf = ByteArrayStream()
        buf.write(body.toArray())
        let res = this.req(
            "PROPFIND",
            path,
            buf,
            {
                req =>
                if (self) {
                    req.headers.add("Depth", "0")
                } else {
                    req.headers.add("Depth", "1")
                }
                req.headers.add("Content-Type", "application/xml;charset=UTF-8")
                req.headers.add("Accept", "application/xml,text/xml")
                req.headers.add("Accept-Charset", "utf-8")
                req.headers.add("Accept-Encoding", "")
            }
        )
        if (res.status != 207) {
            throw PathException("PROPFIND", path, res.status)
        }
        var r = StringReader(res.body)
        var h = ResponseHandler()
        let p = XmlParser(h)
        let x = r.readToEnd()
        p.parse(x)
        return h.responses
    }

    func docopy(method: String, oldpath: String, newpath: String, overwrite: Bool): (UInt16, InputStream) {
        let res = this.req(
            method,
            oldpath,
            None,
            {
                r =>
                r.headers.add("Destination", URL.mergePaths(this.root, newpath).toString())
                r.headers.add("Overwrite", if (overwrite) {
                    "T"
                } else {
                    "F"
                })
            }
        )
        return (res.status, res.body)
    }
    func copymove(method: String, oldpath: String, newpath: String, overwrite: Bool): Unit {
        let (status, body) = this.docopy(method, oldpath, newpath, overwrite)
        match (status) {
            case 201 | 204 => ()
            case 207 =>
                let content = StringReader(body).readToEnd()
                println("TODO handle ${method} - ${oldpath} multistatus result ${content}")
            case 409 => 
                this.createParentCollection(newpath)
                this.docopy(method, oldpath, newpath, overwrite)
            case _ => throw PathException(method, oldpath, status)
        }
    }

    func put(path: String, stream: InputStream): UInt16 {
        let res = this.req("PUT", path, stream, None)
        return res.status
    }

    func createParentCollection(itemPath: String): Unit {
        let p = Path(itemPath).directoryName
        if (let Some(v) <- p) {
            if (v.toString() == "." || v.toString() == "/") {
                return
            }
            this.mkdirAll(v.toString())
        }
    }
}

class WebdavResponse <: ToString {
    WebdavResponse(var href: String, let props: ArrayList<Props>) {}
    public func toString():String {
        return "href: ${href}, \tprops: ${props}"
    }
}

class Props <: ToString {
    var status:String = ""
    var name:String= ""
    var size:String = ""
    var contentType:String= ""
    var etag:String= ""
    var modified:String= ""
    var isDir = false
    init(){}
    public func toString():String {
        return "status: ${status}, name: ${name}, size: ${size}, contentType: ${contentType}, etag: ${etag}, modified: ${modified}, isDir: ${isDir}"
    }
}

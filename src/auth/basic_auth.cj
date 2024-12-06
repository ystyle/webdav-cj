package webdav.auth

import net.http.{HttpHeaders, HttpResponse, HttpRequest, Client as HttpClient}
import encoding.base64.toBase64String

public class BasicAuth <: Authenticator {
    public BasicAuth(let user: String, let pwd: String) {}
    public func authorize(c: HttpClient, req: HttpRequest, path: String): Unit {
        let basicauth = toBase64String("${user}:${pwd}".toArray())
        req.headers.set("Authorization", "Basic ${basicauth}")
    }
    public func verify(c: HttpClient, res: HttpResponse, path: String): Bool {
        if (res.status == 401) {
            throw Exception("Authorize ${path}: 401")
        }
        return false
    }
    public func clone(): Authenticator {
        return this
    }
    public func toString(): String {
        return "BasicAuth login: ${this.user}"
    }
    public func close(): Unit {
    }
}


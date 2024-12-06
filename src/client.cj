package webdav

import net.http.{HttpHeaders, HttpRequest, HttpResponse, HttpStatusCode, ClientBuilder, Client as HttpClient, CookieJar, HttpResponseBuilder, HttpRequestBuilder}
import webdav.auth.{IAuthorizer, NewAutoAuth}
import std.time.Duration

let XInhibitRedirect: String = "X-Gowebdav-Inhibit-Redirect"

public class WebdavClient {
    var root: String
    var headers = HttpHeaders()
    var interceptor: Option<(method: String, req: HttpRequest) -> Unit> = None
    var c: HttpClient
    var auth: IAuthorizer
    var timeout: Duration = Duration.second * 30
    var retry = 20
    var jar: ?CookieJar = None
    public init(uri: String, user: String, passwd: String) {
        this(uri, NewAutoAuth(user, passwd))
    }
    public init(uri: String, auth: IAuthorizer) {
        this.c = ClientBuilder().build()
        this.root = fixSlash(uri)
        this.auth = auth
    }
    public func setHeader(key: String, value: String): Unit {
        this.headers.add(key, value)
    }
    public func setInterceptor(interceptor: (method: String, req: HttpRequest) -> Unit) {
        this.interceptor = interceptor
    }
    public func setTimeout(timeout: Duration): Unit {
        this.timeout = timeout
        this.buildClient()
    }
    public func setJar(jar: CookieJar): Unit {
        this.jar = jar
        this.buildClient()
    }
    func buildClient() {
        let cb = ClientBuilder().readTimeout(this.timeout).writeTimeout(this.timeout)
        if (let Some(v) <- this.jar) {
            cb.cookieJar(this.jar)
        }
        this.c = cb.build()
    }


}

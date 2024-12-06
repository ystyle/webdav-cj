package webdav.auth

import net.http.{HttpHeaders, HttpResponse, HttpRequest, Client as HttpClient}
import std.io.{InputStream}
import std.collection.ArrayList
import std.sync.ReentrantMutex

public type AuthFactoryFn = (c: HttpClient, resp: HttpResponse, path: String) -> Authenticator

public class AuthChangedException <: Exception {
    let redo: Bool
    init() {
        super()
        this.redo = false
    }
    init(redo: Bool) {
        super()
        this.redo = redo
    }
}

public interface IAuthorizer {
    func newAuthenticator(body: ?InputStream): (Authenticator, ?InputStream)
    func addAuthenticator(key: String, fn: AuthFactoryFn): Unit
}

public class Authorizer <: IAuthorizer {
    let factories = ArrayList<Authfactory>()
    let defAuthMux = ReentrantMutex()
    var defAuth: Option<Authenticator> = None
    public func addAuthenticator(key: String, fn: AuthFactoryFn): Unit {
        for (f in this.factories) {
            if (f.key == key) {
                throw Exception("Authenticator exists: ${key}")
            }
        }
        this.factories.append(Authfactory(key, fn))
    }
    public func newAuthenticator(body: ?InputStream): (Authenticator, ?InputStream) {
        var newdefauth: Authenticator
        synchronized(this.defAuthMux) {
            newdefauth = this.defAuth.getOrThrow().clone()
        }
        let aas = AuthShim(this.factory, body, newdefauth)
        return (aas, body)
    }

    func factory(c: HttpClient, res: HttpResponse, path: String): Authenticator {
        let headers = res.headers.get("Www-Authenticate")
        var auth: Authenticator = NoAuth()
        if (headers.size > 0) {
            let auths = ArrayList<Authenticator>()
            for (f in this.factories) {
                for (header in headers) {
                    if (header.toAsciiLower().contains(f.key.toAsciiLower())) {
                        res.headers.set("Www-Authenticate", header)
                        try {
                            let auth = f.create(c, res, path)
                            auths.append(auth)
                            break
                        } catch (_) {
                        }
                    }
                }
            }
            match (auths.size) {
                case 0 => throw Exception()
                case 1 => auth = auths[0]
                case _ =>
                    // todo negoauth
                    auth = auths[0]
            }
        }
        this.setDefaultAuthenticator(auth)
        return auth
    }

    func setDefaultAuthenticator(auth: Authenticator): Unit {
        synchronized(this.defAuthMux) {
            this.defAuth = auth
        }
    }
}

public interface Authenticator <: ToString {
    func authorize(c: HttpClient, req: HttpRequest, path: String): Unit
    func verify(c: HttpClient, res: HttpResponse, path: String): Bool
    func clone(): Authenticator
    func close(): Unit
}

public func NewAutoAuth(login: String, secret: String): IAuthorizer {
    var az = Authorizer()
    az.defAuth = NullAuth()
    az.addAuthenticator(
        "basic",
        {
            c, res, path => return BasicAuth(login, secret)
        }
    )
    return az
}

class Authfactory {
    Authfactory(let key: String, let create: AuthFactoryFn) {}
}

class AuthShim <: Authenticator {
    let factory: AuthFactoryFn
    let body: ?InputStream
    var auth: Authenticator
    init(factory: AuthFactoryFn, body: ?InputStream, auth: Authenticator) {
        this.factory = factory
        this.body = body
        this.auth = auth
    }
    public func authorize(c: HttpClient, req: HttpRequest, path: String): Unit {
        this.auth.authorize(c, req, path)
    }
    public func verify(c: HttpClient, res: HttpResponse, path: String): Bool {
        var redo: Bool
        try {
            redo = this.auth.verify(c, res, path)
        } catch (e: AuthChangedException) {
            try {
                this.auth = this.factory(c, res, path)
                return true
            } catch (_) {
                return false
            }
        }
        return redo
    }
    public func clone(): Authenticator {
        return NoAuth()
    }
    public func toString(): String {
        return "AuthShim"
    }
    public func close(): Unit {
    }
}

class NoAuth <: Authenticator {
    init() {
    }
    public func authorize(c: HttpClient, req: HttpRequest, path: String): Unit {
    }
    public func verify(c: HttpClient, res: HttpResponse, path: String): Bool {
        if (let Some(_) <- res.headers.getFirst("Www-Authenticate")) {
            throw AuthChangedException()
        }
        return false
    }
    public func clone(): Authenticator {
        return this
    }
    public func toString(): String {
        return "NoAuth"
    }
    public func close(): Unit {
    }
}

class NullAuth <: Authenticator {
    init() {
    }
    public func authorize(c: HttpClient, req: HttpRequest, path: String): Unit {
        req.headers.set("X-Gowebdav-Inhibit-Redirect", "1")
    }
    public func verify(c: HttpClient, res: HttpResponse, path: String): Bool {
        throw AuthChangedException(true)
    }
    public func clone(): Authenticator {
        return this
    }
    public func toString(): String {
        return "NullAuth"
    }
    public func close(): Unit {
    }
}

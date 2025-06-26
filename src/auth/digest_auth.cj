package webdav.auth

import std.collection.HashMap
import net.http.{HttpResponse, HttpRequest, Client as HttpClient}
import std.random.Random
import encoding.hex.toHexString
import crypto.digest.{MD5}
import std.crypto.digest.digest

public class DigestAuth <: Authenticator {
    let user: String
    let pwd: String
    let digestParts: HashMap<String, String>
    public init(login: String, secret: String, resp: HttpResponse) {
        this(login, secret, parserDigestParts(resp))
    }
    init(login: String, secret: String, parts: HashMap<String, String>) {
        this.user = login
        this.pwd = secret
        this.digestParts = parts
    }

    public func authorize(c: HttpClient, req: HttpRequest, path: String): Unit {
        this.digestParts["uri"] = path
        this.digestParts["method"] = req.method
        this.digestParts["username"] = this.user
        this.digestParts["password"] = this.pwd
        req.headers.set("Authorization", getDigestAuthorization(this.digestParts))
    }
    public func verify(c: HttpClient, res: HttpResponse, path: String): Bool {
        if (res.status == 401) {
            if(isStaled(res)) {
                return true
            } else {
                throw Exception("Authorize ${path}: 401")
            }
        }
        return false
    }
    public func clone(): Authenticator {
        let parts = this.digestParts.clone()
        return DigestAuth(this.user, this.pwd, parts)
    }
    public func toString(): String {
        return "DigestAuth login: ${this.user}"
    }
    public func close(): Unit {
    }
}

func parserDigestParts(resp: HttpResponse): HashMap<String, String> {
    let result = HashMap<String, String>()
    if (let Some(v) <- resp.headers.getFirst("Www-Authenticate")) {
        let wantedHeaders = ["nonce", "realm", "qop", "opaque", "algorithm", "entityBody"]
        let responseHeaders = v.split(",")
        for (r in responseHeaders) {
            for (w in wantedHeaders) {
                if (r.contains(w)) {
                    result[w] = r.split("=", 2)[1].trimRight("=").trimLeft("=")
                }
            }
        }
    }
    return result
}

func getmd5(text: String): String {
    return toHexString(digest(MD5(), text))
}

func getCnonce(): String {
    var b = Array<UInt8>(0, item: 0)
    for (i in 0..b.size) {
        b.set(i, Random().nextUInt8())
    }
    return toHexString(b)
}

func getDigestAuthorization(digestParts: HashMap<String, String>): String {
    let d = digestParts
    var ha1: String = ""
    var ha2: String = ""
    var nonceCount = 1
    var cnonce = getCnonce()
    var response = ""

    // 'ha1' value depends on value of "algorithm" field
    match (d["algorithm"]) {
        case "MD5" => ha1 = getmd5(d["username"] + ":" + d["realm"] + ":" + d["password"])
        case "MD5-sess" =>
            let m = getmd5(d["username"] + ":" + d["realm"] + ":" + d["password"])
            ha1 = getmd5("${m}:${nonceCount}:${cnonce}")
        case _ => print("")
    }

    // 'ha2' value depends on value of "qop" field
    match (d["qop"]) {
        case "auth" | "" => ha2 = getmd5(d["method"] + ":" + d["uri"])
        case "auth-int" =>
            if (d["entityBody"] != "") {
                ha2 = getmd5(d["method"] + ":" + d["uri"] + ":" + getmd5(d["entityBody"]))
            }
        case _ => print("")
    }

    // 'response' value depends on value of "qop" field
    match (d["qop"]) {
        case "" => response = getmd5("${ha1}:${d["nonce"]}:${ha2}")
        case "auth" | "auth-int" => response = getmd5(
            "${ha1}:${d["nonce"]}:${nonceCount}:${cnonce}:${d["nonce"]}:${ha2}")
        case _ => println("")
    }
    var authorization = 'Digest username="${d["username"]}", realm="${d["realm"]}", nonce="${d["nonce"]}", uri="${d["uri"]}", nc=${nonceCount}, cnonce="${cnonce}", response="${response}"'
    if (d["qop"] != "") {
        authorization += ', qop=${d["qop"]}'
    }
    if (d["opaque"] != "") {
        authorization += ', opaque="${d["opaque"]}"'
    }
    return authorization
}

func isStaled(rs: HttpResponse): Bool {
    if (let Some(v) <- rs.headers.getFirst("Www-Authenticate")) {
        let directives = v.split(",")
        for (directive in directives) {
            let arr = directive.split("=")
            if (arr.size == 2 && arr[0] == "stale" && arr[1] == "true") {
                return true
            }
        }
    }
    return false
}

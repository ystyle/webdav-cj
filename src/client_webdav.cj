package webdav

import net.http.{HttpStatusCode}
import std.time.{DateTime, DateTimeFormat}
import std.fs.Path
import std.collection.ArrayList
import std.convert.*
import std.io.{ByteArrayStream, InputStream, BufferedInputStream, SeekPosition}

public class PathException <: Exception {
    init(op: String, path: String, status: UInt16) {
        super("${op} ${path}: ${status}")
    }
    init(op: String, path: String, e: Exception) {
        super("${op} ${path}: ${e}")
    }
}

extend WebdavClient {
    public func connect(): Unit {
        let resp = this.options("/")
        if (resp.status != HttpStatusCode.STATUS_OK) {
            throw PathException("Connect", this.root, resp.status)
        }
    }
    public func readDir(path: String): ArrayList<FileInfo> {
        let p = fixSlashes(path)
        let body = """
    <d:propfind xmlns:d='DAV:'>
			<d:prop>
				<d:displayname/>
				<d:resourcetype/>
				<d:getcontentlength/>
				<d:getcontenttype/>
				<d:getetag/>
				<d:getlastmodified/>
			</d:prop>
		</d:propfind>
    """
        var list = ArrayList<FileInfo>()
        try {
            let responses = this.propfind(p, false, body)
            for (response in responses) {
                let propitem = response.props[0]
                var size = 0
                if (!propitem.isDir) {
                    size = Int64.parse(propitem.size)
                }
                let modified = DateTime.parse(propitem.modified, DateTimeFormat.RFC1123)
                let fi = FileInfo(p + propitem.name, propitem.name, propitem.contentType, size, modified,
                    propitem.etag, propitem.isDir)
                list.append(fi)
            }
        } catch (e: PathException) {
            throw PathException("readDir", path, e)
        }
        return list
    }
    public func stat(path: String): ?FileInfo {
        let p = fixSlashes(path)
        let body = """
    <d:propfind xmlns:d='DAV:'>
			<d:prop>
				<d:displayname/>
				<d:resourcetype/>
				<d:getcontentlength/>
				<d:getcontenttype/>
				<d:getetag/>
				<d:getlastmodified/>
			</d:prop>
		</d:propfind>
    """
        var info: ?FileInfo = None
        try {
            let responses = this.propfind(p, true, body)
            for (response in responses) {
                let propitem = response.props[0]
                let size = Int64.parse(propitem.size)
                let modified = DateTime.parse(propitem.modified, DateTimeFormat.RFC1123)
                let fi = FileInfo(this.root + response.href, propitem.name, propitem.contentType, size, modified,
                    propitem.etag, propitem.isDir)
                info = fi
                break
            }
        } catch (e: PathException) {
            throw PathException("readDir", path, e)
        }
        return info
    }
    public func remove(path: String): Unit {
        let res = this.req("DELETE", path, None, None)
        if (!ArrayList<UInt16>([200, 204, 404]).contains(res.status)) {
            throw PathException("remote", path, res.status)
        }
    }
    public func mkdir(path: String): Unit {
        let p = fixSlashes(path)
        let status = this.mkcol(p)
        if (status != 201) {
            throw PathException("Mkdir", path, status)
        }
    }
    public func mkdirAll(path: String): Unit {
        let p = fixSlashes(path)
        let status = this.mkcol(p)
        if (status == 201) {
            return
        }
        if (status == 409) {
            let paths = p.split("/")
            var sub = "/"
            for (e in paths) {
                if (e == "") {
                    continue
                }
                sub += e + "/"
                let status = this.mkcol(sub)
                if (status != 201) {
                    throw PathException("mkdirAll", sub, status)
                }
            }
            return
        }
        throw PathException("mkdirAll", path, status)
    }
    public func rename(oldpath: String, newpath: String, overwrite: Bool): Unit {
        this.copymove("MOVE", oldpath, newpath, overwrite)
    }
    public func copy(oldpath: String, newpath: String, overwrite: Bool): Unit {
        this.copymove("COPY", oldpath, newpath, overwrite)
    }
    public func read(path: String): Array<Byte> {
        let input = this.readStream(path)
        return readAll(input)
    }
    public func readStream(path: String): InputStream {
        let res = this.req("GET", path, None, None)
        if (res.status != 200) {
            throw PathException("readStream", path, res.status)
        }
        return res.body
    }
    public func readStreamRange(path: String, offset: Int64, length: Int64): InputStream {
        let res = this.req("GET", path, None,
            {
            req => if (length > 0) {
                req.headers.add("Range", "bytes=${offset}-${offset+length-1}")
            } else {
                req.headers.add("Range", "bytes=${offset}-")
            }
        })
        if (res.status == 206) {
            return res.body
        }
        if (res.status == 200) {
            let bs = readAll(res.body)
            let bas = ByteArrayStream(length)
            bas.write(bs[offset..offset + length])
            return bas
        }
        throw PathException("ReadStream", path, res.status)
    }
    public func write(path: String, data: Array<Byte>): Unit {
        let bas = ByteArrayStream(data.size)
        bas.write(data)
        bas.seek(SeekPosition.Current(0))
        this.writeStream(path, BufferedInputStream(bas))
    }
    public func writeStream(path: String, data: InputStream): Unit {
        this.createParentCollection(path)
        let status = this.put(path, data)
        if (status == 200 || status == 201 || status == 204) {
            return
        }
        throw PathException("writeite", path, status)
    }
}

public class FileInfo {
    let path: String
    let name: String
    let contentType: String
    let size: Int64
    let modified: DateTime
    let etag: String
    let isDir: Bool
    // init(root:String,href:String, resp:Props) {
    //     let size = Int64.parse(resp.size)
    //     let modified = DateTime.parse(resp.modified)
    //     this(root+href, resp.name, resp.contentType, size, modified, resp.etag, resp.isDir)
    // }
    public init(path: String, name: String, contentType: String, size: Int64, modified: DateTime, etag: String,
        isDir: Bool) {
        this.path = path
        this.name = name
        this.contentType = contentType
        this.size = size
        this.modified = modified
        this.etag = etag
        this.isDir = isDir
    }
}

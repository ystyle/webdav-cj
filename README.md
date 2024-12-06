# webdav-cj
仓颉Webdav操作客户端库

### 安装依赖
```toml
[dependencies]
  webdav = { git = "https://github.com/ystyle/webdav-cj", branch = "master"}
```
### 示例
```cj
import webdav.WebdavClient
main():Unit {
    let client = WebdavClient("http://localhost:6065", "admin", "admin")
    client.connect()
    client.mkdirAll("/testdir/test1/test2/test3")
    let fileinfos = client.readDir("/testdir")
    for (fi in fileinfos) {
        println(fi.path)
    }
}
```

### api
- `WebdavClient(username:String, password:String)`: 初始化Webdav客户端
  - `public func setHeader(key:String, value:String)`: 设置header
  - `public func interceptor(interceptor: (method: String, req: HttpRequest) -> Unit)`: 设置公共处理器
  - `public func setTimeout(timeout: Duration): Unit`: 设置超时时间
  - `public func setJar(jar: CookieJar): Unit`: 设置cookie
  - `public func connect(): Unit`: 连接服务器，失败抛出异常
  - `public func readDir(path: String): ArrayList<FileInfo>`: 读取文件夹信息，失败抛出异常
  - `public func stat(path: String): ?FileInfo `: 获取文件详细信息，失败抛出异常
  - `public func remove(path: String): Unit`: 删除文件，失败抛出异常
  - `public func mkdir(path: String): Unit`: 创建文件夹，失败抛出异常
  - `public func mkdirAll(path: String): Unit`： 递归创建文件夹，失败抛出异常
  - `public func rename(oldpath: String, newpath: String, overwrite: Bool): Unit`: 修改文件名，失败抛出异常
  - `public func copy(oldpath: String, newpath: String, overwrite: Bool): Unit`： 复制文件，失败抛出异常
  - `public func read(path: String): Array<Byte>`: 读取文件，失败抛出异常
  - `public func readStream(path: String): InputStream`: 按流读取文件，失败抛出异常
  - `public func readStreamRange(path: String, offset: Int64, length: Int64): InputStream`: 按流读取文件， 可以设置开始位置， 不支持设置开始位置的服务器会先下载全文件，失败抛出异常
  - `public func write(path: String, data: Array<Byte>): Unit`： 写入文件，失败抛出异常
  - `public func writeStream(path: String, data: InputStream): Unit`: 用文件流写入文件，失败抛出异常

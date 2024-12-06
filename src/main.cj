package webdav

main():Unit {
    let client = WebdavClient("http://localhost:6065", "admin", "admin")
    client.connect()
    client.mkdirAll("/testdir/test1/test2/test3")
    let fileinfos = client.readDir("/testdir")
    for (fi in fileinfos) {
        println(fi.path)
    }
    let stat = client.stat("/xml-demo/main.go")
    if (let Some(fi) <- stat) {
        println("name: ${fi.name}, etag: ${fi.etag}")    
    }
    let bs = client.read("/xml-demo/main.go")
    println(String.fromUtf8(bs))

    client.write("/testdir/log.txt", "你好".toArray())
}
package webdav

import std.unittest.*
import std.unittest.testmacro.*
@Test
class TestClient {
    func newClient() {
        return WebdavClient("http://localhost:6065", "admin", "admin")
    }
    @TestCase
    func testConnect() { 
        let client = this.newClient()
        client.connect()
    }
    @TestCase
    func testMkdir() {
        let client = this.newClient()
        client.connect()
        client.mkcol("/testaa")
    }
}

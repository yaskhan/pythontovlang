module mypy

pub type IPCException = string
pub type BadStatus = string
pub type IPCAny = []u8 | bool | f64 | i64 | int | map[string]IPCAny | string

pub struct IPCBase {
pub mut:
	name    string
	timeout ?f64
	buffer  []u8
	closed  bool
}

pub fn new_ipc_base(name string, timeout ?f64) IPCBase {
	return IPCBase{
		name:    name
		timeout: timeout
		buffer:  []u8{}
		closed:  false
	}
}

pub fn (mut b IPCBase) frame_from_buffer() ?[]u8 {
	if b.buffer.len == 0 {
		return none
	}
	frame := b.buffer.clone()
	b.buffer = []u8{}
	return frame
}

pub fn (mut b IPCBase) read(size int) string {
	return b.read_bytes(size).bytestr()
}

pub fn (mut b IPCBase) read_bytes(size int) []u8 {
	if size <= 0 || b.buffer.len == 0 {
		return []u8{}
	}
	n := if size < b.buffer.len { size } else { b.buffer.len }
	data := b.buffer[..n].clone()
	b.buffer = b.buffer[n..].clone()
	return data
}

pub fn (mut b IPCBase) write(data string) {
	b.write_bytes(data.bytes())
}

pub fn (mut b IPCBase) write_bytes(data []u8) {
	b.buffer << data
}

pub fn (mut b IPCBase) close() {
	b.closed = true
}

pub struct IPCClient {
pub mut:
	base IPCBase
}

pub fn new_ipc_client(name string, timeout ?f64) !IPCClient {
	return IPCClient{
		base: new_ipc_base(name, timeout)
	}
}

pub struct IPCServer {
pub mut:
	base IPCBase
}

pub fn new_ipc_server(name string, timeout ?f64) !IPCServer {
	return IPCServer{
		base: new_ipc_base(name, timeout)
	}
}

pub fn (mut s IPCServer) cleanup() {
	s.base.close()
}

pub fn read_status(status_file string) !map[string]IPCAny {
	_ = status_file
	return map[string]IPCAny{}
}

pub interface IPCMessage {
	write(mut buf WriteBuffer)
}

pub struct WriteBuffer {
pub mut:
	data []u8
}

pub fn (mut b WriteBuffer) write_u8(v u8) {
	b.data << v
}

pub fn (mut b WriteBuffer) write_u32(v u32) {
	b.data << u8((v >> 24) & 0xff)
	b.data << u8((v >> 16) & 0xff)
	b.data << u8((v >> 8) & 0xff)
	b.data << u8(v & 0xff)
}

pub fn (mut b WriteBuffer) write_str(s string) {
	b.write_u32(u32(s.len))
	b.data << s.bytes()
}

pub fn (b WriteBuffer) getvalue() []u8 {
	return b.data.clone()
}

pub struct ReadBuffer {
pub mut:
	data []u8
	pos  int
}

pub fn new_read_buffer(data []u8) ReadBuffer {
	return ReadBuffer{
		data: data.clone()
		pos:  0
	}
}

pub fn (mut b ReadBuffer) read_u8() !u8 {
	if b.pos >= b.data.len {
		return error('EOF')
	}
	v := b.data[b.pos]
	b.pos++
	return v
}

pub fn (mut b ReadBuffer) read_u32() !u32 {
	if b.pos + 4 > b.data.len {
		return error('EOF')
	}
	v := (u32(b.data[b.pos]) << 24) | (u32(b.data[b.pos + 1]) << 16) | (u32(b.data[b.pos + 2]) << 8) | u32(b.data[b.pos + 3])
	b.pos += 4
	return v
}

pub fn (mut b ReadBuffer) read_str() !AnyNode {
	length := int(b.read_u32()!)
	if b.pos + length > b.data.len {
		return error('EOF')
	}
	s := b.data[b.pos..b.pos + length].bytestr()
	b.pos += length
	return s
}

pub fn send(mut connection IPCBase, data IPCMessage) {
	mut buf := WriteBuffer{}
	data.write(mut buf)
	connection.write_bytes(buf.getvalue())
}

pub fn receive(mut connection IPCBase) !ReadBuffer {
	return new_read_buffer(connection.read_bytes(100000))
}

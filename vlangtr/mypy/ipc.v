// ipc.v — Inter-process communication abstractions
// Translated from mypy/ipc.py to V 0.5.x
//
// Work in progress by Antigravity. Started: 2026-03-22 13:00

module mypy

import os
import net

// Message header size (4 bytes in network order)
pub const header_size = 4

// IPCException — exception for IPC errors
pub type IPCException = string

// IPCBase — base class for client-server communication
pub struct IPCBase {
pub mut:
	name         string
	timeout      f64
	message_size ?int
	buffer       []u8
}

// new_ipc_base creates a new IPCBase
pub fn new_ipc_base(name string, timeout ?f64) IPCBase {
	return IPCBase{
		name:         name
		timeout:      timeout or { 0.0 }
		message_size: none
		buffer:       []u8{}
	}
}

// frame_from_buffer returns complete frame from buffer
pub fn (mut b IPCBase) frame_from_buffer() ?[]u8 {
	size := b.buffer.len
	if size < header_size {
		return none
	}

	if b.message_size == none {
		// unpack("!L", buffer[:4]) — big-endian 4-byte unsigned int
		b.message_size = (int(b.buffer[0]) << 24) | (int(b.buffer[1]) << 16) | (int(b.buffer[2]) << 8) | int(b.buffer[3])
	}

	msg_size := b.message_size or { return none }
	if size < msg_size + header_size {
		return none
	}

	// Return data without header
	data := b.buffer[header_size..header_size + msg_size]
	b.buffer = b.buffer[header_size + msg_size..]
	b.message_size = none
	return data.clone()
}

// read reads string from IPC connection
pub fn (mut b IPCBase) read(size int) string {
	data := b.read_bytes(size)
	return string(data)
}

// read_bytes reads bytes from IPC connection until complete frame
pub fn (mut b IPCBase) read_bytes(size int) []u8 {
	// Simplified version — without platform-dependent code
	mut bdata := []u8{}

	for {
		frame := b.frame_from_buffer()
		if frame != none {
			bdata = frame or { []u8{} }
			break
		}

		// In real implementation here would be reading from socket/pipe
		// For simplicity return empty data
		break
	}

	return bdata
}

// write writes string to IPC connection
pub fn (mut b IPCBase) write(data string) {
	b.write_bytes(data.bytes())
}

// write_bytes writes bytes to IPC connection
pub fn (mut b IPCBase) write_bytes(data []u8) {
	// Encode length as big-endian 4-byte unsigned int
	mut encoded := []u8{}
	encoded << u8((data.len >> 24) & 0xFF)
	encoded << u8((data.len >> 16) & 0xFF)
	encoded << u8((data.len >> 8) & 0xFF)
	encoded << u8(data.len & 0xFF)

	// Add data
	for byte in data {
		encoded << byte
	}

	// In real implementation here would be sending to socket/pipe
	_ = encoded
}

// close closes connection
pub fn (mut b IPCBase) close() {
	b.buffer = []u8{}
}

// IPCClient — client side of IPC connection
pub struct IPCClient {
pub mut:
	base IPCBase
}

// new_ipc_client creates a new IPCClient
pub fn new_ipc_client(name string, timeout ?f64) !IPCClient {
	mut client := IPCClient{
		base: new_ipc_base(name, timeout)
	}

	// In real implementation here would be connection to socket
	// client.base.connection = socket.socket(socket.AF_UNIX)
	// client.base.connection.connect(name)

	return client
}

// IPCServer — server side of IPC connection
pub struct IPCServer {
pub mut:
	base           IPCBase
	sock_directory string
}

pub const ipc_server_buffer_size = 2 ^ 16

// new_ipc_server creates a new IPCServer
pub fn new_ipc_server(name string, timeout ?f64) !IPCServer {
	// Generate unique name
	mut full_name := name
	mut sock_directory := ''

	// On Unix create temporary directory for socket
	sock_directory = os.tmpdir() + os.path_separator + 'mypy_ipc_' + name
	os.mkdir(sock_directory, os.default_dir_mod) or {
		// ignore
	}
	full_name = sock_directory + os.path_separator + name + '.sock'

	mut server := IPCServer{
		base:           new_ipc_base(full_name, timeout)
		sock_directory: sock_directory
	}

	// In real implementation here would be socket creation
	// server.sock = socket.socket(socket.AF_UNIX)
	// server.sock.bind(full_name)
	// server.sock.listen(1)

	return server
}

// cleanup cleans up server resources
pub fn (mut s IPCServer) cleanup() {
	if s.sock_directory != '' {
		os.rm(s.sock_directory) or {
			// ignore
		}
	}
	s.base.close()
}

// BadStatus — exception for status errors
pub type BadStatus = string

// read_status reads status file
pub fn read_status(status_file string) !map[string]any {
	if !os.file_exists(status_file) {
		return BadStatus('No status file found')
	}

	data := os.read_file(status_file) or { return BadStatus('Cannot read status file') }

	// Parse JSON
	// In simplified version return empty map
	return map[string]any{}
}

// IPCMessage — base class for IPC messages
pub interface IPCMessage {
	write(buf &WriteBuffer)
}

// WriteBuffer — buffer for writing IPC messages
pub struct WriteBuffer {
pub mut:
	data []u8
}

pub fn (mut b WriteBuffer) write_u8(v u8) {
	b.data << v
}

pub fn (mut b WriteBuffer) write_u32(v u32) {
	b.data << u8((v >> 24) & 0xFF)
	b.data << u8((v >> 16) & 0xFF)
	b.data << u8((v >> 8) & 0xFF)
	b.data << u8(v & 0xFF)
}

pub fn (mut b WriteBuffer) write_str(s string) {
	b.write_u32(s.len)
	for byte in s.bytes() {
		b.data << byte
	}
}

pub fn (b WriteBuffer) getvalue() []u8 {
	return b.data.clone()
}

// ReadBuffer — buffer for reading IPC messages
pub struct ReadBuffer {
pub:
	data []u8
	pos  int
}

pub fn new_read_buffer(data []u8) ReadBuffer {
	return ReadBuffer{
		data: data
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
	v := (u32(b.data[b.pos]) << 24) | (u32(b.data[b.pos + 1]) << 16) | (u32(b.data[b.pos + 2]) << 8) | u32(b.data[
		b.pos + 3])
	b.pos += 4
	return v
}

pub fn (mut b ReadBuffer) read_str() !string {
	len := b.read_u32() or { return error('EOF') }
	if b.pos + len > b.data.len {
		return error('EOF')
	}
	s := string(b.data[b.pos..b.pos + len])
	b.pos += len
	return s
}

// send sends IPCMessage through connection
pub fn send(connection &IPCBase, data IPCMessage) {
	mut buf := WriteBuffer{
		data: []u8{}
	}
	data.write(&mut buf)
	connection.write_bytes(buf.getvalue())
}

// receive receives IPCMessage from connection
pub fn receive(connection &IPCBase) !ReadBuffer {
	bdata := connection.read_bytes(100000)
	if bdata.len == 0 {
		return error('No data received')
	}
	return new_read_buffer(bdata)
}

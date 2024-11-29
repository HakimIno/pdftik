// src/types.zig
const std = @import("std");
const napi = @cImport({
    @cInclude("node_api.h");
});

pub const JsError = error{
    InvalidArguments,
    ConversionFailed,
    OutOfMemory,
};

pub fn throwError(env: napi.napi_env, message: []const u8) napi.napi_value {
    const result: napi.napi_value = undefined;
    _ = napi.napi_throw_error(env, null, message.ptr);
    return result;
}

package bff

import "base:intrinsics"
import "base:runtime"
import "core:reflect"
import "core:io"
import "core:bytes"
import "core:mem"

marshal :: proc(stream: io.Stream, s: ^$T)
{
    type_info := type_info_of(T)
    root_is_struct := reflect.is_struct(type_info)
    assert(root_is_struct, "type is not a struct") 

    root := uintptr(s)
    for &field in reflect.struct_fields_zipped(T)
    {
        if reflect.struct_tag_get(field.tag, "bff") == "@ignore" do continue

        field_name_length := len(field.name)
        io.write_ptr(stream, &field_name_length, size_of(int))
        io.write_string(stream, field.name)

        if reflect.is_slice(field.type)
        {
            element_typeid := reflect.typeid_elem(field.type.id)
            element_type_info := type_info_of(element_typeid)
            raw_slice := cast(^runtime.Raw_Slice)(root + field.offset)
            length := raw_slice.len * element_type_info.size
            io.write_ptr(stream, &length, size_of(int))
            io.write_ptr(stream, raw_slice.data, length)
        }
        else if reflect.is_string(field.type)
        {
            raw_string := cast(^runtime.Raw_String)(root + field.offset)
            io.write_ptr(stream, &raw_string.len, size_of(int))
            io.write_ptr(stream, raw_string.data, raw_string.len)
        }
        else if reflect.is_array(field.type)
        {
            data := cast(rawptr)(root + field.offset)
            io.write_ptr(stream, &field.type.size, size_of(int))
            io.write_ptr(stream, data, field.type.size)
        }
        else if reflect.is_rune(field.type) || reflect.is_byte(field.type) ||
            reflect.is_integer(field.type) || reflect.is_float(field.type)
        {
            data := cast(rawptr)(root + field.offset)
            io.write_ptr(stream, &field.type.size, size_of(int))
            io.write_ptr(stream, data, field.type.size)
        }
    }
}

unmarshal :: proc(s: ^$T, data: []byte) -> (success: bool)
{
    type_info := type_info_of(T)
    if !reflect.is_struct(type_info) do return

    raw_fields, raw_fields_error := make(map[string]runtime.Raw_Slice, intrinsics.type_struct_field_count(T), context.temp_allocator)
    if raw_fields_error != .None do return

    for i := 0; i < len(data);
    {
        name_length := (cast(^int)&data[i])^
        i += size_of(int)
        
        name := transmute(string)runtime.Raw_String{cast([^]u8)&data[i], name_length}
        i += name_length

        value_size := (cast(^int)&data[i])^
        i += size_of(int)

        value_data := runtime.Raw_Slice{cast(rawptr)&data[i], value_size}
        i += value_size

        raw_fields[name] = value_data
    }

    root := uintptr(s)
    for &field in reflect.struct_fields_zipped(T)
    {
        if reflect.struct_tag_get(field.tag, "bff") == "@ignore" do continue

        raw_field, has_raw_field := raw_fields[field.name]
        if !has_raw_field do continue

        if reflect.is_slice(field.type)
        {
            element_typeid := reflect.typeid_elem(field.type.id)
            element_type_info := type_info_of(element_typeid)

            raw_slice := cast(^runtime.Raw_Slice)(root + field.offset)
            raw_slice.data = raw_field.data
            raw_slice.len = raw_field.len / element_type_info.size
        }
        else if reflect.is_string(field.type)
        {
            raw_string := cast(^runtime.Raw_String)(root + field.offset)
            raw_string.data = transmute([^]byte)raw_field.data
            raw_string.len = raw_field.len
        }
        else if reflect.is_array(field.type)
        {
            dst := cast(rawptr)(root + field.offset)
            mem.copy(dst, raw_field.data, raw_field.len)
        }
        else if reflect.is_rune(field.type) || reflect.is_byte(field.type) ||
            reflect.is_integer(field.type) || reflect.is_float(field.type)
        {
            dst := cast(rawptr)(root + field.offset)
            mem.copy(dst, raw_field.data, raw_field.len)
        }
    }

    return true
}
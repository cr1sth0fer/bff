package bff

import "base:intrinsics"
import "base:runtime"
import "core:reflect"
import "core:io"
import "core:bytes"
import "core:mem"

marshal :: proc(stream: io.Stream, s: ^$T) -> (ok: bool)
{
    type_info := type_info_of(T)
    if !reflect.is_struct(type_info) do return

    root := uintptr(s)
    for &field in reflect.struct_fields_zipped(T)
    {    
        field_name_length := len(field.name)
        io.write_ptr(stream, &field_name_length, size_of(int))
        io.write_string(stream, field.name)
        
        using runtime
        #partial switch variant in reflect.type_info_base(field.type).variant
        {
            case Type_Info_Slice:
                raw_slice := cast(^runtime.Raw_Slice)(root + field.offset)
                length := raw_slice.len * variant.elem_size
                io.write_ptr(stream, &length, size_of(int))
                io.write_ptr(stream, raw_slice.data, length)

            case Type_Info_String:
                if variant.is_cstring do continue
                raw_string := cast(^Raw_String)(root + field.offset)
                io.write_ptr(stream, &raw_string.len, size_of(int))
                io.write_ptr(stream, raw_string.data, raw_string.len)

            case Type_Info_Struct, Type_Info_Union, Type_Info_Enum, Type_Info_Rune,
                Type_Info_Integer, Type_Info_Float, Type_Info_Array:
                data := cast(rawptr)(root + field.offset)
                io.write_ptr(stream, &field.type.size, size_of(int))
                io.write_ptr(stream, data, field.type.size)
        }
    }
    return true
}

unmarshal :: proc(s: ^$T, data: []byte) -> (ok: bool)
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
        raw_field, has_raw_field := raw_fields[field.name]
        if !has_raw_field do continue
        
        using runtime
        #partial switch variant in reflect.type_info_base(field.type).variant
        {
            case Type_Info_Slice:
                element_typeid := reflect.typeid_elem(field.type.id)
                element_type_info := type_info_of(element_typeid)
                raw_slice := cast(^runtime.Raw_Slice)(root + field.offset)
                raw_slice.data = raw_field.data
                raw_slice.len = raw_field.len / element_type_info.size

            case Type_Info_String:
                if variant.is_cstring do continue
                raw_string := cast(^runtime.Raw_String)(root + field.offset)
                raw_string.data = transmute([^]byte)raw_field.data
                raw_string.len = raw_field.len

            case Type_Info_Struct, Type_Info_Union, Type_Info_Enum, Type_Info_Rune,
                Type_Info_Integer, Type_Info_Float, Type_Info_Array:
                dst := cast(rawptr)(root + field.offset)
                mem.copy(dst, raw_field.data, raw_field.len)
        }
    }

    return true
}
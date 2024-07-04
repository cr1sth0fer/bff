package bff

import "core:os"
import "core:fmt"
import "core:testing"
import "core:bytes"

@(test)
test :: proc(t: ^testing.T)
{
    Ann :: struct
    {
        float0: f32,
        int0: int,
    }

    Foo :: struct
    {
        rune0: rune,

        int0: i8,
        int1: i16,
        int2: i32,
        int3: i64,

        uint0: u8,
        uint1: u16,
        uint2: u32,
        uint3: u64,

        float0: f16,
        float1: f32,
        float2: f64,

        name0: string,
        name1: string,

        array0: [8]int,
        array1: [16]i16,

        slice0: []int,
        slice1: []u64,

        ann0: Ann,
    }

    foo: Foo
    foo.rune0 = 'x'

    foo.int0 = 10
    foo.int1 = 11
    foo.int2 = 12
    foo.int3 = 13

    foo.uint0 = 20
    foo.uint1 = 21
    foo.uint2 = 22
    foo.uint3 = 23

    foo.float0 = 11.11
    foo.float1 = 22.22
    foo.float2 = 33.33

    foo.name0 = "Name 0"
    foo.name1 = "Name 1"

    foo.array0 = {8, 7, 6, 5, 4, 3, 2, 1}
    foo.array1 = {8, 7, 6, 5, 4, 3, 2, 1, 1, 2, 3, 4, 5, 6, 7, 8}

    foo.slice0 = {1, 2, 3, 4, 5}
    foo.slice1 = {1, 2, 3, 4, 5, 6, 7, 8, 9, 0}

    foo.ann0 = {88.88, 1234}

    fmt.println("Struct:", foo)

    buffer: bytes.Buffer
    bytes.buffer_init_allocator(&buffer, 0, 2048, context.temp_allocator)
    stream := bytes.buffer_to_stream(&buffer)

    marshal(stream, &foo)
    fmt.println("BFF Buffer Size:", len(buffer.buf))

    foo1: Foo
    unmarshal(&foo1, buffer.buf[:])

    fmt.println("Unmarshaled Struct:", foo1)
}
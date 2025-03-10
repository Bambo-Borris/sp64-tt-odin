package sp64_tt

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

import rl "vendor:raylib"

/*
TODO:
    - Support file logging via multi-logger
    Bambo 06/03/25

    - Make use of arena allocator in the image extraction code
    Bambo 10/03/25
*/

EntryMapKey :: [2]u16

Image_File_Info :: struct {
    separator_start: int,
    offset:          int,
    width:           u16,
    height:          u16,
}

SEPARATOR_LENGTH :: 0x48
SEQUENCE := [9]byte{0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x03}

main :: proc() {
    options: log.Options = log.Default_File_Logger_Opts
    options -= {.Short_File_Path, .Line, .Procedure}
    context.logger = log.create_console_logger(.Debug, options)
    defer log.destroy_file_logger(context.logger)

    if len(os.args) < 2 {
        log.error("Missing path to packed texture file!")
        return
    }

    path: string = os.args[1]

    if !os.exists(path) {
        log.error("Invalid path to packed texture file!")
        return
    }


    if !unpack_textures(path) {
        log.error("Failed to unpack textures from file!")
    }
}

unpack_textures :: proc(path: string) -> bool {

    file_contents := os.read_entire_file(path) or_return
    log.info("Successfully packed texture file contents")

    if len(file_contents) < len(SEQUENCE) {
        log.error("Malformed packed texture format")
        return false
    }

    // Let's scan over the byte array of file contents and look for our magical separator pattern
    // if we find it, we'll add the separators ID to an array which we use
    // afterwards to extract the images.
    separator_locations := make([dynamic]int)
    defer delete(separator_locations)

    for i in 0 ..< len(file_contents) {
        buff: [9]byte

        if i + len(buff) >= len(file_contents) do break

        does_match := true
        for j in 0 ..< len(SEQUENCE) {
            if file_contents[i + j] == SEQUENCE[j] {
                buff[j] = file_contents[i + j]
            } else {
                does_match = false
                break
            }
        }

        if does_match {
            append(&separator_locations, i)
        }
    }

    log.infof("Identified %v separators in packed texture file", len(separator_locations))

    entries_per_size: map[EntryMapKey][dynamic]Image_File_Info

    defer {
        for _, &e in entries_per_size do delete(e)

        delete(entries_per_size)
    }

    // Identify image data
    for &sep, index in separator_locations {
        if index > len(separator_locations) - 2 do break

        width, height: u16

        mem.copy(&width, &file_contents[sep + 0x2C], size_of(u16))
        mem.copy(&height, &file_contents[sep + 0x2C + size_of(u16)], size_of(u16))

        if entries_per_size[{width, height}] == nil {
            entries_per_size[{width, height}] = make([dynamic]Image_File_Info)
        }

        append(&entries_per_size[{width, height}], Image_File_Info{separator_start = sep, offset = sep, width = width, height = height})
    }

    for _, &v in entries_per_size {
        for file_info, index in v {
            extracted_image_data := get_image_data(file_contents[:], file_info)
            defer delete(extracted_image_data)

            builder: strings.Builder
            strings.builder_init(&builder)
            defer strings.builder_destroy(&builder)

            dimension_string := fmt.tprintf("%v_x_%v", file_info.width, file_info.height)
            path_string := fmt.tprintf("%v_%v_%v.png", file_info.separator_start, dimension_string, index)

            save_image_to_disk(path_string, extracted_image_data[:], {file_info.width, file_info.height})
            log.debugf("Will save image %v", path_string)
        }

        free_all(context.temp_allocator)
    }

    return true
}


get_image_data :: proc(image_data: []byte, image_info: Image_File_Info) -> (out_list: [dynamic]u16) {
    size := (16 * (int(image_info.width) * int(image_info.height))) / 8
    start := image_info.separator_start + SEPARATOR_LENGTH

    for i := 0; i < (size - 1); i += 2 {
        pixel: u16
        mem.copy(&pixel, &image_data[start + i], size_of(u16))
        append(&out_list, pixel)
    }

    return
}

save_image_to_disk :: proc(path: string, image_data: []u16, size: [2]u16) {
    image: rl.Image

    image.format = .UNCOMPRESSED_R8G8B8A8
    image.width = cast(i32)size.x
    image.height = cast(i32)size.y
    image.mipmaps = 1

    data_converted: [dynamic]u8
    reserve(&data_converted, 256 * 256 * 4)

    for i in 0 ..< len(image_data) {
        pixel := convert_argb16_to_rgba32(image_data[i])

        original_size := len(data_converted)
        resize(&data_converted, original_size + 4)

        data_converted[original_size + 0] = pixel[0]
        data_converted[original_size + 1] = pixel[1]
        data_converted[original_size + 2] = pixel[2]
        data_converted[original_size + 3] = pixel[3]
    }

    image.data = &data_converted[0]

    path_cstr := strings.clone_to_cstring(path, context.temp_allocator)
    result := rl.ExportImage(image, path_cstr)

    if !result {
        log.error("Unable to save", path, "to disk")
    }
}

convert_argb16_to_rgba32 :: proc(in_pixel: u16) -> (out_pixel: [4]u8) {
    out_pixel[3] = (in_pixel & 0x8000 != 0) ? 255 : 0 // alpha
    out_pixel[0] = cast(u8)(((in_pixel & 0x7C00) >> 10) * 255 / 31)
    out_pixel[1] = cast(u8)(((in_pixel & 0x3E0) >> 5) * 255 / 31)
    out_pixel[2] = cast(u8)((in_pixel & 0x1F) * 255 / 31)
    return
}

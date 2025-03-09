package sp64_tt

import "core:log"
import "core:mem"
import "core:os"

// import rl "vendor:raylib"

/*
TODO:
    - Support file logging via multi-logger
    Bambo 06/03/25
    
*/

EntryMapKey :: [2]u16

Image_File_Info :: struct {
    separator_start: int,
    offset:          int,
    width:           u16,
    height:          u16,
}

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
    SEPARATOR_LENGTH :: 0x48
    SEQUENCE := [9]byte{0x00, 0x00, 0x00, 0x00, 0x08, 0x00, 0x00, 0x00, 0x03}

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

    return true
}

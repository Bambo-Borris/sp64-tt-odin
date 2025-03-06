package sp64_tt

import "core:log"
import "core:os"

main :: proc() {
    context.logger = log.create_console_logger()
    defer log.destroy_file_logger(context.logger)

    when ODIN_OS == .Windows {
        if len(os.args) <= 1 {
            log.errorf("Missing path to packed texture file!")
            return
        }
    } else {
        if len(os.args) < 1 {
            log.error("Missing path to packed texture file!")
            return
        }
    }

    path: string

    when ODIN_OS == .Windows {
        path = os.args[1]
    } else {
        path = os.args[0]
    }

    if !os.exists(path) {
        log.error("Invalid path to packed texture file!")
        return
    }


    if !unpack_textures(path) {
        log.error("Failed to unpack textures from file!")
    }
}

unpack_textures :: proc(path: string) -> bool {
    return true
}


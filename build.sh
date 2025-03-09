if [ ! -d "build" ]; then
    mkdir -p "build"
fi

commonFlags=(
    "-warnings-as-errors"
    "-show-timings"
    "-strict-style"
    "-vet"
    "-use-separate-modules"
)

debugFlags=(
    "-o:none"
)

odin build "src/" "${commonFlags[@]}" "${debugFlags[@]}" -out:"build/tt" -build-mode:exe -debug

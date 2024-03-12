# binarify

Container Image to Self-Extracting Binary

Influenced by [NilsIrl/dockerc](https://github.com/NilsIrl/dockerc), but with bash and without FUSE.

Rather than using FUSE which requires installing FUSE package, it just extracts image like Container runtimes.

It will take more time to launch for image to be extracted.

It is not recommended for real-life use.

It uses `jq`, `crun`, `umoci` at runtime.

### Usage

`binarify --image docker://oven/bun --output bun.binary`

`./bun.binary --mount myapp:/data:ro --env API=123456789 -- run /data/app.bash`


#### To build `binarify`:

`binarify` is itself self-extracting execuatble.

`./makebin.sh binarify.sh utils/crun utils/umoci utils/jq > binarify`

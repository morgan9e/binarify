#!/bin/bash
set -e 

IMAGE=""
OUTPUT=""

for flag in "$@"; do
  case $flag in
    --output)
      shift
      OUTPUT="$1"
      shift
      ;;
    --image)
      shift
      IMAGE="$1"
      shift
      ;;
  esac
done

if [ -z "$IMAGE" ]; then echo Please specify --image; exit 1; fi
if [ -z "$OUTPUT" ]; then echo Please specify --output; exit 1; fi

if test -v WORKDIR; then
  if [ -d "$WORKDIR" ]; then
    echo [*] WORKDIR $WORKDIR
    OUTPUT="$WORKDIR/$OUTPUT"
  fi
fi

if [ -f "$OUTPUT" ]; then echo File $OUTPUT already exists.; exit 1; fi

echo [*] Binarifing $IMAGE...

TMP=$(mktemp -d)

echo [*] Pulling OCI Image..
skopeo copy $IMAGE oci:$TMP/image:latest;

##

echo [*] Unpacking OCI Image...
./umoci unpack --rootless --image $TMP/image:latest $TMP/bundle

echo [*] Tarballing OCI Bundle..
tar -c -C $TMP -f $TMP/bundle.tar ./bundle;

cat << 'EOF' > $TMP/init.sh
#!/bin/bash

echo [*] Working at \"$(pwd)\"
cd "$(dirname "$0")"

echo [*] Extracting OCI bundle...
tar xf bundle.tar

echo [*] Modifing config.json...

CONFIG_FILE="./bundle/config.json"
TEMP_FILE="temp_config.$$"
MOUNTS_ARGS=()
ENV_VARS=()
CMD_ARGS=()
IN_CMD_ARGS=false

for arg in "$@"; do
  if [ "$IN_CMD_ARGS" = false ]; then
    case "$arg" in
      --mount)
        IN_MOUNT=true
        ;;
      --env)
        IN_ENV=true
        ;;
      --)
        IN_CMD_ARGS=true
        ;;
      *)
        if [ "$IN_MOUNT" = true ]; then
          MOUNTS_ARGS+=("$arg")
          IN_MOUNT=false
        elif [ "$IN_ENV" = true ]; then
          ENV_VARS+=("$arg")
          IN_ENV=false
        else
          echo "** Non flag argument found. Anything after this will be passed to container."
          IN_CMD_ARGS=true
        fi
        ;;
    esac
  else
    CMD_ARGS+=("$arg")
  fi
done

for mount in "${MOUNTS_ARGS[@]}"; do
  src=$(echo "$mount" | cut -d: -f1)
  dst=$(echo "$mount" | cut -d: -f2 | cut -d: -f1)
  opts=$(echo "$mount" | grep -oE ':[^:]+$' | cut -d: -f2)

  if [[ "$opts" == "ro" ]]; then
    mountOpts=("ro")
  else
    mountOpts=("rbind" "rw")
  fi

  mountOptsJson=$(printf '%s\n' "${mountOpts[@]}" | ./jq -R . | ./jq -s .)
  
  ./jq --arg dst "$dst" --arg src "$src" --argjson opts "$mountOptsJson" \
    '.mounts += [{"destination": $dst, "type": "bind", "source": $src, "options": $opts}]' \
    "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
done

for env_var in "${ENV_VARS[@]}"; do
  ./jq --arg env_var "$env_var" '.process.env += [$env_var]' \
    "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
done

if [ ${#CMD_ARGS[@]} -gt 0 ]; then
  for cmd_arg in "${CMD_ARGS[@]}"; do
    ./jq --arg cmd_arg "$cmd_arg" '.process.args += [$cmd_arg]' \
      "$CONFIG_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$CONFIG_FILE"
  done
fi

echo [*] Running crun...
A=$(basename $(realpath .))
./crun run -b bundle ${A#*.}
EOF

echo [*] Creating Self-Extracting Binary...
init="$TMP/init.sh"
files=("$TMP/bundle.tar" "./jq" "./umoci" "./crun")
out="$TMP/output.sh"

# echo [*] Tarballing OCI Image..
# tar -c -C $TMP -f $TMP/image.tar ./image;

# cat << 'EOF' > $TMP/init.sh
# #!/bin/bash

# echo [*] Working at \"$(pwd)\"
# cd "$(dirname "$0")"

# echo [*] Extracting OCI Image...
# ./busybox tar xf image.tar

# echo [*] Unpacking OCI Image...
# ./busybox sh -c "./umoci unpack --rootless --image image:latest bundle"

# echo [*] Running crun...
# A=$(basename $(realpath .))
# ./busybox sh -c "./crun run -b bundle ${A#*.}"
# ./busybox sh
# EOF

# echo [*] Creating Self-Extracting Binary...
# init="$TMP/init.sh"
# files=("$TMP/image.tar" "./busybox" "./umoci" "./crun")
# out="$TMP/output.sh"

cat << EOF > ${out}
#!/bin/bash

PAYLOADSTART=__PAYLOADSTART__

TEMP_DIR=\$(mktemp -d)

cleanup() {
    rm -rf "\$TEMP_DIR"
}
trap cleanup EXIT

tail -n +\$PAYLOADSTART "\$0" | tar x -C "\$TEMP_DIR"

chmod +x "\$TEMP_DIR/$(basename ${init})"

WORKDIR="\$(pwd)"

cd \$TEMP_DIR

WORKDIR=\"$WORKDIR\" EXTRACTED="\$TEMP_DIR" "\$TEMP_DIR/$(basename ${init})" "\$@"

exit 0

EOF

echo "## DATA ##" >> ${out}

tmptar=$(mktemp)
tar cf "$tmptar" -C "$(dirname $init)" "$(basename $init)"
for file in "${files[@]}"; do
  tar rf "$tmptar" -C "$(dirname $file)" "$(basename $file)"
done

for i in $(tar tf $tmptar); do echo [*] - $i; done

cat $tmptar >> "$out"
payload_line=$(grep -n '^## DATA ##' -oa ${out} | cut -d: -f1)
payload_line=$((payload_line + 1))

sed -i "s/PAYLOADSTART=__PAYLOADSTART__/PAYLOADSTART=${payload_line}/" ${out}

cat "$out" > "$OUTPUT";
chmod +x "$OUTPUT";

echo [*] Successfully binarified to $OUTPUT
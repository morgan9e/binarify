#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: $0 <init> <files...>" >&2
    exit 1
fi

if [ -t 1 ]; then
    echo "Error: Refusing writing to terminal." >&2
    exit 1
fi


out=$(mktemp)
init="$1"
shift
files=("$@")

cat > ${out} << EOF
#!/bin/bash 

PAYLOAD_LINE=__PAYLOAD_LINE__

TEMP_DIR=\$(mktemp -d)

cleanup() {
    rm -rf "\$TEMP_DIR"
}
trap cleanup EXIT

tail -n +\$PAYLOAD_LINE "\$0" | tar x -C "\$TEMP_DIR"

chmod +x "\$TEMP_DIR/${init}"

WORKDIR="\$(pwd)"

cd \$TEMP_DIR

WORKDIR="\$WORKDIR" EXTRACTED="\$TEMP_DIR" "\$TEMP_DIR/${init}" "\$@"

exit 0

EOF

echo "## DATA ##" >> ${out}

tmptar=$(mktemp)
tar cf "$tmptar" -C "$(dirname $init)" "$(basename $init)"
for file in "${files[@]}"; do
  tar rf "$tmptar" -C "$(dirname $file)" "$(basename $file)"
done
echo "makebin init: $(basename $init), files: (" $(tar tf $tmptar) ")" >&2;
cat "$tmptar" >> "$out"
rm "$tmptar"

payload_line=$(grep -n '^## DATA ##' -oa ${out} | cut -d: -f1)
payload_line=$((payload_line + 1))

sed -i "s/PAYLOAD_LINE=__PAYLOAD_LINE__/PAYLOAD_LINE=${payload_line}/" ${out}

cat ${out};

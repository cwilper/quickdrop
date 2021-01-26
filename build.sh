#!/usr/bin/env bash

rm -rf build > /dev/null 2>&1
mkdir build
installer=build/install.sh
cat > $installer << "EOF"
#!/usr/bin/env bash

die() {
  >&2 echo "Error: $1"
  exit 1
}

cd
[[ -d .quickdrop ]] && [[ $1 != -f ]] && die "~/.quickdrop already exists. Remove before installing."

tempfile=$(mktemp)
cleanup() {
  [ -f $tempfile ] && rm $tempfile
}
trap cleanup EXIT

cat > $tempfile << EOF
EOF
tar -cz --exclude=config --exclude=*.log .quickdrop | base64 -b 80 >> $installer
echo "EOF" >> $installer
cat >> $installer << "EOF"

cat $tempfile | base64 -d | tar -xz

[[ -d .quickdrop ]] || die "Installation failed"
cp .quickdrop/config.dist .quickdrop/config
~/.quickdrop/bin/qdsetup
EOF
chmod 755 $installer

#!/bin/sh

echo "Setting confine passwd (enabling ssh)"

passwd <<EOF
confine
confine
EOF


pw_warn_file=/root/.password-warning

cat >> "/etc/profile" <<EOF

# Show a reminder to set a proper password.
if [ -f "$pw_warn_file" ]; then
        cat $pw_warn_file
fi
EOF

cat >> "/root/.password-warning" <<EOF

**WARNING:**

Please remember to change root's password using ``passwd root``.
Then you may remove ``$pw_warn_file``
to suppress this warning.

EOF

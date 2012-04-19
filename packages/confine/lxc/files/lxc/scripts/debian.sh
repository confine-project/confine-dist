



customize_rootfs() {
    SL_NAME=$1

    cat <<EOF >> $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/network/interfaces

#auto internal
#     iface internal inet dhcp

EOF


    cat <<EOF > $LXC_IMAGES_PATH/$SL_NAME/rootfs/etc/hostname
$SL_NAME
EOF



}








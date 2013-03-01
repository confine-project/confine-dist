source ./vct.sh

VCT_SERVER_DIR=${VCT_VIRT_DIR}/server
VCT_SERVER_VERSION='0.8a5' # get latest with: $ python -c 'import controller; print controller.VERSION'


install_server () {
    local CURRENT_VERSION=$(python -c "from controller import get_version; print get_version();" || echo false)
    
    vct_sudo apt-get update
    vct_sudo apt-get install -y --force-yes python-pip
    
    vct_sudo mkdir -p $VCT_SERVER_DIR/{media/templates,static,private/exp_data}
    vct_sudo chown -R $VCT_USER {$VCT_SERVER_DIR,server}
    
    # executes pip commands on /tmp because of garbage they generate
    CURRENT=$(pwd) && cd /tmp
    if [[ ! $(pip freeze|grep confine-controller) ]]; then
        # First time controller gets installed
        vct_sudo pip install confine-controller==$VCT_SERVER_VERSION
    else
        # An older version is present, just go ahead and proceed with normal way
        vct_sudo python $CURRENT/server/manage.py upgradecontroller --pip --controller_version $VCT_SERVER_VERSION
    fi
    vct_sudo controller-admin.sh install_requirements
    
    # cleanup possible pip shit
    vct_sudo rm -fr {pip-*,build,src}
    
    cd -
    vct_sudo python server/manage.py setupceleryd --username $VCT_USER
    vct_sudo python server/manage.py setupapache
    vct_sudo python server/manage.py setupfirmware
    
    # We need postgres to be online, just making sure it is.
    vct_sudo service postgresql start
    vct_sudo python server/manage.py setuppostgres --db_name controller --db_user confine --db_password confine
    vct_sudo python server/manage.py syncdb --noinput
    vct_sudo python server/manage.py migrate --noinput
    
    # Load initial datat into the database
    vct_sudo python server/manage.py loaddata firmwareconfig
    vct_sudo python server/manage.py loaddata vctfirmwareconfig
    # Move static files in a place where apache can get them
    python server/manage.py collectstatic --noinput
    
    vct_sudo python server/manage.py setuptincd --noinput --safe \
        --tinc_address="${VCT_SERVER_TINC_IP}" \
        --tinc_privkey="${VCT_KEYS_DIR}/tinc/rsa_key.priv" \
        --tinc_pubkey="${VCT_KEYS_DIR}/tinc/rsa_key.pub"
    python server/manage.py updatetincd
    
    vct_sudo python server/manage.py restartservices
    if [[ $CURRENT_VERSION != false ]]; then
        # Per version upgrade specific operations
        vct_sudo python server/manage.py postupgradecontroller --specifics --from $CURRENT_VERSION
    fi
    
    # Create a vct user, default VCT group and provide initial auth token to vct user
    cat <<- EOF | python server/manage.py shell > /dev/null
		from users.models import *
		if not User.objects.filter(username='vct').exists():
		 User.objects.create_superuser('vct', 'vct@example.com', 'vct')
		
		group, created = Group.objects.get_or_create(name='vct', allow_slices=True, allow_nodes=True)
		user = User.objects.get(username='vct')
		Roles.objects.get_or_create(user=user, group=group, is_admin=True);
		token_file = open('${VCT_KEYS_DIR}/id_rsa.pub', 'ro')
		AuthToken.objects.get_or_create(user=user, data=token_file.read())
		EOF
}

install_server



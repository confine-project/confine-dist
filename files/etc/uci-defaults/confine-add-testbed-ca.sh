#!/bin/sh
# Add CONFINE testbed CA to the ones accepted by OpenSSL.
# Based on http://wiki.openwrt.org/doc/howto/wget-ssl-certs.
SSL_CERT_DIR=/etc/ssl/certs
TESTBED_CA_CERT=confine-testbed-ca.pem

cd $SSL_CERT_DIR || exit 1
test -r $TESTBED_CA_CERT || exit 1
cert_hash=$(openssl x509 -hash -noout -in $TESTBED_CA_CERT) \
	&& ln -sf $TESTBED_CA_CERT $cert_hash.0

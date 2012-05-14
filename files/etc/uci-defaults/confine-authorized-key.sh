#!/bin/sh

echo "Setting CONFINE authorized key (enabling ssh)"


mkdir -p /etc/dropbear/

echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXWcW2C6kMEQp5O91eBisEdxh4isS1ydsjM6/BTI0PefyjRT+dmjtVaQDy0qWoeTzQ36DNy0s5IcMwtTlNTx/COhn5l9QeN8OVwtg75slTLisCXQob6BT/CPBGYnoNyISNmJ0vpeMzdFXfXB2oolLfLIbQ8+5tkrSaFlgJmOo4zVZqe98gIfLuJM3EAFpw3GJIw1Ni92V2T/z5nyc8SIKgxch8wMqtCaK8MaKcQv1uxfdqGLbMpJVuqCcqAw0p0hae84Lga6XeNEgBmwyepM0BG6KXgQztXc/9wmEw+vw1/ubM7jn4a+Umyrh0x5mzs2PGPDzLzqpRAN7YMPhyelDp root@confine" >> /etc/dropbear/authorized_keys



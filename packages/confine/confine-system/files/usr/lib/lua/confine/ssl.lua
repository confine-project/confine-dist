--[[



]]--

--- CONFINE ssl library.
module( "confine.ssl", package.seeall )

local luci   = require "luci"

local tools  = require "confine.tools"
local dbg    = tools.dbg

RSA_HEADER   = "%-%-%-%-%-BEGIN RSA PUBLIC KEY%-%-%-%-%-"
RSA_TRAILER  = "%-%-%-%-%-END RSA PUBLIC KEY%-%-%-%-%-"
SSH_HEADER   = "ssh%-rsa "


SHA256_LEN_MAX = ((256/8)*2)
SHA256_LEN_MIN = (SHA256_LEN_MAX - 4)
local OPENSSL_BIN          = "/usr/bin/openssl"

function dgst_sha256( dst )
	local dgst = luci.util.exec( OPENSSL_BIN.." dgst -sha256 "..dst )
	local sha = (type(dgst)=="string") and dgst:match("[%x]+\n$"):gsub("\n","")
--	dbg( "dst=%s sha=%s openssl_result=%s", tostring(dst), tostring(sha), tostring(dgst))
	return sha
end

function get_ssh_pubkey_pem( file )
	return luci.util.exec( "ssh-keygen -f "..file.." -i -m PEM" )
end
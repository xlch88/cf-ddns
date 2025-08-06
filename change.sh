#!/bin/bash

auth_token=$1
zone_identifier=$2
record_name=$3
interface_name=$4
ip_type=$5
dns_type="A"

if [[ $ip_type == 6 ]]; then
	dns_type="AAAA"
fi

function log() {
	echo "[$(date +'%Y-%m-%d %H:%M:%S')][$interface_name][$record_name] $1"
}

log "Getting IPv$ip_type address..."
ip=$(curl -s -$ip_type --interface $interface_name http://$ip_type.ip.moeeye.cn/?my)
if [[ -z "$ip" ]]; then
	log "cannot get ip !" >&2
	exit 1
fi
log "now public IP: $ip"

auth_header=(-H "Authorization: Bearer $auth_token")

record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?name=$record_name&type=$dns_type" \
	"${auth_header[@]}" -H "Content-Type: application/json")

if [[ -z "$record" ]] || [[ "$record" == *'"count":0'* ]]; then
	log "No DNS record found, creating a new one..."

	create=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records" \
		"${auth_header[@]}" -H "Content-Type: application/json" \
		--data "{\"type\":\"$dns_type\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":false}")

	if echo "$create" | grep -q '"success":true'; then
		log "create new success ! IP: $ip"
	else
		log "create error : $create" >&2
		exit 1
	fi
	exit 0
fi

record_identifier=$(echo "$record" | sed 's/.*"id":"\([^"]*\)".*/\1/')
old_ip=$(echo "$record" | sed 's/.*"content":"\([^"]*\)".*/\1/')
log "now DNS IP: $old_ip"

if [[ "$ip" == "$old_ip" ]]; then
	log "IP not change."
	exit 0
fi

update=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
	"${auth_header[@]}" -H "Content-Type: application/json" \
	--data "{\"type\":\"$dns_type\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":120,\"proxied\":false}")

if echo "$update" | grep -q '"success":true'; then
	log "update success ! old: $old_ip, new IP: $ip"
else
	log "update fail : $update" >&2
	exit 1
fi

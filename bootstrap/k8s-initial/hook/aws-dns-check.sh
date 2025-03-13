#!/bin/bash

set -euo pipefail

# Get existing Route 53 A records (Name, TTL, IP)
get_existing_records() {
    aws route53 list-resource-record-sets --hosted-zone-id "$AWS_53_HOSTED_ZONE_ID" \
        --query "ResourceRecordSets[?Type=='A'].[Name,TTL,ResourceRecords[0].Value]" \
        --output json
}

# Upsert (create or update) a Route 53 A record
upsert_route53_record() {
    local dns="$1"
    local ip="$2"
    local hosted_zone_id="$AWS_53_HOSTED_ZONE_ID"
    local ttl=60

    echo "🔄 Upserting record: $dns -> $ip (TTL: $ttl)"
    aws route53 change-resource-record-sets --hosted-zone-id "$hosted_zone_id" --change-batch '{
        "Changes": [{
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "'"$dns"'",
                "Type": "A",
                "TTL": '"$ttl"',
                "ResourceRecords": [{"Value": "'"$ip"'"}]
            }
        }]
    }'
}

# Delete a Route 53 A record using the exact TTL from the record
delete_route53_record() {
    local dns="$1"
    local ttl="$2"
    local ip="$3"
    local hosted_zone_id="$AWS_53_HOSTED_ZONE_ID"

    aws route53 change-resource-record-sets --hosted-zone-id "$hosted_zone_id" --change-batch '{
        "Changes": [{
            "Action": "DELETE",
            "ResourceRecordSet": {
                "Name": "'"$dns"'",
                "Type": "A",
                "TTL": '"$ttl"',
                "ResourceRecords": [{"Value": "'"$ip"'"}]
            }
        }]
    }'
}

# Normalize DNS by removing trailing dot
normalize_dns() {
    local dns="$1"
    echo "${dns%.}"
}

# Main function
main() {

    declare -A dns_ip_map

    # Load environment variables from local.env
    for var in $(compgen -v | grep '_DNS$'); do
        base_name="${var%_DNS}"
        dns="${!var}"
        ip_var="${base_name}_IP"
        ip="${!ip_var}"

        if [[ -n "$dns" && -n "$ip" ]]; then
            dns_ip_map["$dns"]="$ip"
            echo "📌 Found from env: $dns -> $ip"
        fi
    done

    # Get existing Route 53 A records (Name, TTL, IP)
    EXISTING_RECORDS=$(get_existing_records)

    # Upsert (create or update) a Route 53 A record
    for target_dns in "${!dns_ip_map[@]}"; do
        target_ip="${dns_ip_map[$target_dns]}"
        normalized_target=$(normalize_dns "$target_dns")


        existing_record=$(echo "$EXISTING_RECORDS" | jq -c --arg dns "$normalized_target" 'map(select((.[0] | rtrimstr(".")) == $dns)) | .[0]')

        if [ "$existing_record" = "null" ]; then
            echo "🆕 No existing record for $target_dns. Creating new record."
            upsert_route53_record "$target_dns" "$target_ip"
        else
            existing_ip=$(echo "$existing_record" | jq -r '.[2]')
            existing_ttl=$(echo "$existing_record" | jq -r '.[1]')
            if [ "$existing_ip" != "$target_ip" ]; then
                echo "🔄 Record for $target_dns has IP $existing_ip, updating to $target_ip."
                upsert_route53_record "$target_dns" "$target_ip"
            else
                echo "✅ Record for $target_dns is correct: $target_ip"
            fi
        fi

        # Delete duplicate Route 53 record using the exact TTL from the record
        duplicates=$(echo "$EXISTING_RECORDS" | jq -c --arg ip "$target_ip" --arg dns "$normalized_target" 'map(select((.[2] == $ip) and ((.[0] | rtrimstr(".")) != $dns)))')
        duplicate_count=$(echo "$duplicates" | jq 'length')
        if [ "$duplicate_count" -gt 0 ]; then
            echo "🗑️ Found $duplicate_count duplicate(s) for IP $target_ip not matching $target_dns."
            echo "$duplicates" | jq -c '.[]' | while read -r dup; do
                dup_dns=$(echo "$dup" | jq -r '.[0]')
                dup_ttl=$(echo "$dup" | jq -r '.[1]')
                delete_route53_record "$dup_dns" "$dup_ttl" "$target_ip"
            done
        fi
    done
}

# Run main function
main

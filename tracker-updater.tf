resource "kubernetes_cron_job_v1" "tracker_updater" {
  metadata {
    name      = "tracker-updater"
    namespace = "homelab"
  }

  spec {
    schedule                    = "0 * * * *"
    successful_jobs_history_limit = 1
    failed_jobs_history_limit     = 3

    job_template {
      metadata {}
      spec {
        ttl_seconds_after_finished = 120
        template {
          metadata {}
          spec {
            restart_policy = "OnFailure"

            container {
              name  = "tracker-updater"
              image = "alpine:latest"

              command = ["/bin/sh"]
              args = [
                "-c",
                <<-EOT
                set -e
                apk add --no-cache curl jq >/dev/null 2>&1

                HOST="http://transmission.homelab:9091/transmission/rpc"
                AUTH="$TR_USER:$TR_PASS"

                # Get session ID (first request returns 409 with the header)
                SESSION_ID=$(curl -s -u "$AUTH" "$HOST" -o /dev/null -D - | grep -i 'X-Transmission-Session-Id' | awk '{print $2}' | tr -d '\r\n')

                # Fetch tracker list, convert to JSON array
                TRACKERS=$(curl -sf "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt" | grep -v '^$' | jq -R . | jq -s .)
                echo "Fetched $(echo "$TRACKERS" | jq length) trackers"

                # Get all torrent IDs
                IDS=$(curl -sf -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION_ID" "$HOST" \
                  -d '{"method":"torrent-get","arguments":{"fields":["id"]}}' | jq '[.arguments.torrents[].id]')
                echo "Found $(echo "$IDS" | jq length) torrents"

                # Add trackers to all torrents
                RESULT=$(curl -sf -u "$AUTH" -H "X-Transmission-Session-Id: $SESSION_ID" "$HOST" \
                  -d "{\"method\":\"torrent-set\",\"arguments\":{\"ids\":$IDS,\"trackerAdd\":$TRACKERS}}")
                echo "Result: $RESULT"
                EOT
              ]

              env {
                name  = "TR_USER"
                value = var.transmission.username
              }
              env {
                name  = "TR_PASS"
                value = var.transmission.password
              }
            }
          }
        }
      }
    }
  }
}

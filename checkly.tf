# Checkly API Monitoring

resource "checkly_check" "homepage" {
  name                      = "Homepage"
  type                      = "API"
  activated                 = true
  frequency                 = 10 # minutes
  use_global_alert_settings = true

  locations = [
    "eu-west-1",
    "eu-central-1",
  ]

  request {
    url              = "https://home.kieranajp.uk"
    follow_redirects = false

    assertion {
      source     = "STATUS_CODE"
      comparison = "EQUALS"
      target     = "302"
    }

    assertion {
      source     = "RESPONSE_TIME"
      comparison = "LESS_THAN"
      target     = "3000"
    }
  }
}

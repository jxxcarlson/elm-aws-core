module AWS.S3 exposing (presignedUrl)

import AWS.Config exposing(Region, ServiceConfig)
import AWS.Service exposing(Service)
import AWS.Credentials exposing(Credentials)
import AWS.Internal.V4
import Time exposing(Month(..))

{-

Outine of the process;

  1. Set up an S3 service, e.g., service = AWS.S3.service (AWS.S3.configure "us-east-1")
  2. Set up the credentials: credentials = AWS.Credentials.fromAccessKeys accessKey secretKey
  3. Set up the request: req = for an unsigned request, see AWS.Http.request (L161)
  4. send service credentials req

We will have to work to implement AWS.Http.presignedRequest
-}



type alias RequestData = {
        region : String
      , bucket : String
      , filename : String
      , time : Time.Posix
      , expiration : Int
      , accessKey : String
      , secretKey : String
      , signature : String
   }


presignedUrl : RequestData -> String
presignedUrl data =
     let
        service_ = service (configure data.region)
        creds = { accessKeyId = data.accessKey, secretAccessKey = data.secretKey, sessionToken = Nothing}
        prefix = "https://s3.amazonaws.com/" ++ data.bucket ++ "/" ++ data.filename ++ "?X-Amz-Algorithm=AWS-HMAC-SHA256"
        elements = [
                prefix
              , "X-Amz-Credential=" ++ data.accessKey ++ "%2F" ++ dateString data.time ++ "%2F" ++ "s3%2Faws_request"
              , "X-Amz-Date=" ++ timeString data.time
              , "X-Amz-Expires=" ++ String.fromInt data.expiration
              , "X-Amz-SignedHeaders=host"
              , "X-Amz-Signature=" ++ AWS.Internal.V4.signature creds service_ data.time data.secretKey
          ]
     in
     String.join "&" elements

dateString : Time.Posix -> String
dateString time = String.fromInt (Time.toYear Time.utc time) ++ toMonthString Time.utc time ++ (String.padLeft 2 '0' <| String.fromInt <| Time.toDay Time.utc time)

toMonthString : Time.Zone -> Time.Posix -> String
toMonthString zone time =
    case Time.toMonth zone time of
        Jan -> "01"
        Feb -> "02"
        Mar -> "03"
        Apr -> "04"
        May -> "05"
        Jun -> "06"
        Jul -> "07"
        Aug -> "08"
        Sep -> "09"
        Oct -> "10"
        Nov -> "11"
        Dec -> "12"


strinFromInt : Int -> String
stringFromInt k =
    k |> String.fromInt |> String.padLeft 2 '0'

timeString : Time.Posix -> String
timeString time =
    dateString time ++ stringFromInt (Time.toHour Time.utc time) ++ stringFromInt (Time.toMinute Time.utc time) ++ stringFromInt (Time.toSecond Time.utc time)

configure : Region -> ServiceConfig
configure region =
      AWS.Config.defineRegional
        "s3"
        "2015-03-31"
        AWS.Config.REST_JSON
        AWS.Config.SignV4
        region

service : ServiceConfig -> Service
service config =
    AWS.Service.service config
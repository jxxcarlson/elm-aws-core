module AWS.S3 exposing(presignedUrl, RequestData, testReq)

import AWS.Config exposing(Region, ServiceConfig)
import AWS.Service exposing(Service)
import AWS.Credentials exposing(Credentials)
import AWS.Internal.V4
import Time exposing(Month(..))

type alias RequestData = {
        region : String
      , bucket : String
      , filepath : String
      , time : Time.Posix
      , expiration : Int
      , accessKey : String
      , secretKey : String
   }

{-|
    To verify correctness, run `presignedUrl (testReq <unixTime>)`
    with an appropriately configured `testReq`.  That is, the
    region, bucket, accessKey and secretKey must be valid.

    Don't commit the last two to GitHub !!!

    There is something wrong with signture.  If I run
    presignedUrl (testReq 1369353600), where 1369353600
    is the Unix Time of May 24, 2013 at 00:00:00 UTC, I get

        e52363bbf1d624e78fb3b1bdc0c2bb40f46a0f2e2e40a78df85c5e9e056afed1

    instead of the official

        aeeed9bbccd4d02ee5c0109b86d86835f995330da4c265957d157751f604d404

    Below is what I get when I run the code with a valid `testReq`:

   <Error>
   <Code>SignatureDoesNotMatch</Code>
   <Message>The request signature we calculated does not match the signature you provided. Check your key and signing method.</Message>
   <AWSAccessKeyId>AKIAJQYJYCIAWH6DGHIQ</AWSAccessKeyId>
   <StringToSign>AWS4-HMAC-SHA256 20201216T151304Z 20201216/us-east-1/s3/aws4_request 708d9b5dc46454b90f7ff1187ee88fb30eb7ee5f290942339f3f80918037ac28</StringToSign>
   <SignatureProvided>cbf7c8cd15542024f0de5a4d74d729146f910895f9b0eb342d990b88a8e547bb</SignatureProvided>
   <StringToSignBytes>41 57 53 34 2d 48 4d 41 43 2d 53 48 41 32 35 36 0a 32 30 32 30 31 32 31 36 54 31 35 31 33 30 34 5a 0a 32 30 32 30 31 32 31 36 2f 75 73 2d 65 61 73 74 2d 31 2f 73 33 2f 61 77 73 34 5f 72 65 71 75 65 73 74 0a 37 30 38 64 39 62 35 64 63 34 36 34 35 34 62 39 30 66 37 66 66 31 31 38 37 65 65 38 38 66 62 33 30 65 62 37 65 65 35 66 32 39 30 39 34 32 33 33 39 66 33 66 38 30 39 31 38 30 33 37 61 63 32 38</StringToSignBytes>
   <CanonicalRequest>GET /vschool/minilatex/test.txt X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAJQYJYCIAWH6DGHIQ%2F20201216%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20201216T151304Z&X-Amz-Expires=86400&X-Amz-SignedHeaders=host host:s3.amazonaws.com host UNSIGNED-PAYLOAD</CanonicalRequest>
   <CanonicalRequestBytes>47 45 54 0a 2f 76 73 63 68 6f 6f 6c 2f 6d 69 6e 69 6c 61 74 65 78 2f 74 65 73 74 2e 74 78 74 0a 58 2d 41 6d 7a 2d 41 6c 67 6f 72 69 74 68 6d 3d 41 57 53 34 2d 48 4d 41 43 2d 53 48 41 32 35 36 26 58 2d 41 6d 7a 2d 43 72 65 64 65 6e 74 69 61 6c 3d 41 4b 49 41 4a 51 59 4a 59 43 49 41 57 48 36 44 47 48 49 51 25 32 46 32 30 32 30 31 32 31 36 25 32 46 75 73 2d 65 61 73 74 2d 31 25 32 46 73 33 25 32 46 61 77 73 34 5f 72 65 71 75 65 73 74 26 58 2d 41 6d 7a 2d 44 61 74 65 3d 32 30 32 30 31 32 31 36 54 31 35 31 33 30 34 5a 26 58 2d 41 6d 7a 2d 45 78 70 69 72 65 73 3d 38 36 34 30 30 26 58 2d 41 6d 7a 2d 53 69 67 6e 65 64 48 65 61 64 65 72 73 3d 68 6f 73 74 0a 68 6f 73 74 3a 73 33 2e 61 6d 61 7a 6f 6e 61 77 73 2e 63 6f 6d 0a 0a 68 6f 73 74 0a 55 4e 53 49 47 4e 45 44 2d 50 41 59 4c 4f 41 44</CanonicalRequestBytes>
   <RequestId>46945144A588F989</RequestId>
   <HostId>m9Y+nemJh4GvfBY0goOYbTH4DSwKWji8GxMGPr77l5IdR31P2lEyFiIcW20BW7goWjJfa3kU+RE=</HostId>
   </Error>
-}
testReq : Int -> RequestData
testReq unixTime = {
      region = "us-east-1"
    , bucket = "examplebucket"
    , filepath = "test.txt"
    , time = Time.millisToPosix (unixTime * 1000)
    , expiration = 86400
    , accessKey = "AKIAIOSFODNN7EXAMPLE"
    , secretKey = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
  }


presignedUrl : RequestData -> String
presignedUrl data =
     let
        service_ = service (configure data.region)
        creds = { accessKeyId = data.accessKey, secretAccessKey = data.secretKey, sessionToken = Nothing}
        url = "https://s3.amazonaws.com/" ++ data.bucket ++ "/" ++ data.filepath ++ "?X-Amz-Algorithm=AWS4-HMAC-SHA256"
        headers = [
               "X-Amz-Credential=" ++ data.accessKey ++ "%2F" ++ dateString data.time ++ "%2F" ++ data.region ++ "%2F" ++ "s3%2Faws4_request"
              , "X-Amz-Date=" ++ timeString data.time
              , "X-Amz-Expires=" ++ String.fromInt data.expiration
              , "X-Amz-SignedHeaders=host"
              , "X-Amz-Signature=" ++ AWS.Internal.V4.signature creds service_ data.time data.secretKey
          ] |> String.join "&"
     in
     url ++ "&" ++ headers


-- AWS HELPERS

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


-- DATE & TIME HELPERS

timeString : Time.Posix -> String
timeString time =
    dateString time
    ++ "T"
    ++ stringFromInt (Time.toHour Time.utc time)
    ++ stringFromInt (Time.toMinute Time.utc time)
    ++ stringFromInt (Time.toSecond Time.utc time)
    ++ "Z"


dateString : Time.Posix -> String
dateString time =
    String.fromInt (Time.toYear Time.utc time)
    ++ toMonthString Time.utc time
    ++ (String.padLeft 2 '0' <| String.fromInt <| Time.toDay Time.utc time)


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


stringFromInt : Int -> String
stringFromInt k =
    k |> String.fromInt |> String.padLeft 2 '0'

